set base_conf [list cluster-enabled yes cluster-node-timeout 1000 cluster-databases 16]

test {Migrate the last slot away from a node using valkey-cli} {
    start_multiple_servers 4 [list overrides $base_conf] {

        # Create a cluster of 3 nodes
        exec src/valkey-cli --cluster-yes --cluster create \
                           127.0.0.1:[srv 0 port] \
                           127.0.0.1:[srv -1 port] \
                           127.0.0.1:[srv -2 port]

        wait_for_condition 1000 50 {
            [CI 0 cluster_state] eq {ok} &&
            [CI 1 cluster_state] eq {ok} &&
            [CI 2 cluster_state] eq {ok}
        } else {
            fail "Cluster doesn't stabilize"
        }

        # Insert some data
        assert_equal OK [exec src/valkey-cli -c -p [srv 0 port] SET foo bar]
        set slot [exec src/valkey-cli -c -p [srv 0 port] CLUSTER KEYSLOT foo]

        # Add new node to the cluster
        exec src/valkey-cli --cluster-yes --cluster add-node \
                     127.0.0.1:[srv -3 port] \
                     127.0.0.1:[srv 0 port]
        
        # First we wait for new node to be recognized by entire cluster
        wait_for_cluster_size 4
        
        wait_for_condition 1000 50 {
            [CI 0 cluster_state] eq {ok} &&
            [CI 1 cluster_state] eq {ok} &&
            [CI 2 cluster_state] eq {ok} &&
            [CI 3 cluster_state] eq {ok}
        } else {
            fail "Cluster doesn't stabilize"
        }

        set newnode_r [valkey_client -3]
        set newnode_id [$newnode_r CLUSTER MYID]

        # Find out which node has the key "foo" by asking the new node for a
        # redirect.
        catch { $newnode_r get foo } e
        assert_match "MOVED $slot *" $e
        lassign [split [lindex $e 2] :] owner_host owner_port
        set owner_r [valkey $owner_host $owner_port 0 $::tls]
        set owner_id [$owner_r CLUSTER MYID]

        # Wait until owner node knows the new node
        wait_for_condition 1000 50 {
            set found 0
            foreach n [get_cluster_nodes $owner_id] {
                if {[dict get $n id] eq $newnode_id} { set found 1; break }
            }
            $found
        } else {
            fail "Owner node does not know the new node yet"
        }

        # Move slot to new node using plain commands
        assert_equal OK [$newnode_r CLUSTER SETSLOT $slot IMPORTING $owner_id]
        assert_equal OK [$owner_r CLUSTER SETSLOT $slot MIGRATING $newnode_id]
        assert_equal {foo} [$owner_r CLUSTER GETKEYSINSLOT $slot 10]
        assert_equal OK [$owner_r MIGRATE 127.0.0.1 [srv -3 port] "" 0 5000 KEYS foo]
        assert_equal OK [$newnode_r CLUSTER SETSLOT $slot NODE $newnode_id]
        assert_equal OK [$owner_r CLUSTER SETSLOT $slot NODE $newnode_id]

        # Using --cluster check make sure we won't get `Not all slots are covered by nodes`.
        # Wait for the cluster to become stable make sure the cluster is up during MIGRATE.
        wait_for_condition 1000 50 {
            [catch {exec src/valkey-cli --cluster check 127.0.0.1:[srv 0 port]}] == 0 &&
            [catch {exec src/valkey-cli --cluster check 127.0.0.1:[srv -1 port]}] == 0 &&
            [catch {exec src/valkey-cli --cluster check 127.0.0.1:[srv -2 port]}] == 0 &&
            [catch {exec src/valkey-cli --cluster check 127.0.0.1:[srv -3 port]}] == 0 &&
            [CI 0 cluster_state] eq {ok} &&
            [CI 1 cluster_state] eq {ok} &&
            [CI 2 cluster_state] eq {ok} &&
            [CI 3 cluster_state] eq {ok}
        } else {
            fail "Cluster doesn't stabilize"
        }

        # Move the only slot back to original node using valkey-cli
        exec src/valkey-cli --cluster reshard 127.0.0.1:[srv -3 port] \
            --cluster-from $newnode_id \
            --cluster-to $owner_id \
            --cluster-slots 1 \
            --cluster-yes

        # The empty node will become a replica of the new owner before the
        # `MOVED` check, so let's wait for the cluster to become stable.
        wait_for_condition 1000 50 {
            [CI 0 cluster_state] eq {ok} &&
            [CI 1 cluster_state] eq {ok} &&
            [CI 2 cluster_state] eq {ok} &&
            [CI 3 cluster_state] eq {ok}
        } else {
            fail "Cluster doesn't stabilize"
        }

        # Check that the key foo has been migrated back to the original owner.
        catch { $newnode_r get foo } e
        assert_equal "MOVED $slot $owner_host:$owner_port" $e

        # Check that the now empty primary node doesn't turn itself into
        # a replica of any other nodes
        wait_for_cluster_propagation
        assert_match *master* [$owner_r role]
    }
}

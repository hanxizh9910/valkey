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

        # Add new node to the cluster
        exec src/valkey-cli --cluster-yes --cluster add-node \
                    127.0.0.1:[srv -3 port] \
                    127.0.0.1:[srv 0 port]
        
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
        
        # Find a node with slots and migrate one slot to the new node
        set source_r [valkey_client 0]
        set source_id [$source_r CLUSTER MYID]
        set slots [$source_r CLUSTER SLOTS]
        set slot [lindex [lindex $slots 0] 0]
        
        # Migrate the slot using valkey-cli
        exec src/valkey-cli --cluster reshard 127.0.0.1:[srv 0 port] \
            --cluster-from $source_id \
            --cluster-to $newnode_id \
            --cluster-slots 1 \
            --cluster-yes

        wait_for_condition 1000 50 {
            [CI 0 cluster_state] eq {ok} &&
            [CI 1 cluster_state] eq {ok} &&
            [CI 2 cluster_state] eq {ok} &&
            [CI 3 cluster_state] eq {ok}
        } else {
            fail "Cluster doesn't stabilize after migration"
        }

        # Now migrate the last slot away from the new node using valkey-cli
        exec src/valkey-cli --cluster reshard 127.0.0.1:[srv -3 port] \
            --cluster-from $newnode_id \
            --cluster-to $source_id \
            --cluster-slots 1 \
            --cluster-yes

        wait_for_condition 1000 50 {
            [CI 0 cluster_state] eq {ok} &&
            [CI 1 cluster_state] eq {ok} &&
            [CI 2 cluster_state] eq {ok} &&
            [CI 3 cluster_state] eq {ok}
        } else {
            fail "Cluster doesn't stabilize after last slot migration"
        }

        # Verify the node with no slots becomes a replica
        wait_for_condition 1000 50 {
            [string match "*slave*" [$newnode_r role]]
        } else {
            fail "Empty node didn't become a replica"
        }
    }
}
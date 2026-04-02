module.exports = async ({github, context}) => {
  const fs = require('fs');
  const fileFailures = JSON.parse(fs.readFileSync('failures.json', 'utf8'));
  const label = 'test-failure';

  // Ensure label exists
  try {
    await github.rest.issues.getLabel({
      owner: context.repo.owner,
      repo: context.repo.repo,
      name: label,
    });
  } catch (e) {
    if (e.status === 404) {
      await github.rest.issues.createLabel({
        owner: context.repo.owner,
        repo: context.repo.repo,
        name: label,
        color: 'e11d48',
        description: 'Test failure detected by CI',
      });
    }
  }

  const existingIssues = await github.paginate(
    github.rest.issues.listForRepo,
    {
      owner: context.repo.owner,
      repo: context.repo.repo,
      labels: label,
      state: 'open',
    },
    (response) => response.data
  );

  const today = new Date().toISOString().split('T')[0];

  for (const fileEntry of fileFailures) {
    const testFile = fileEntry.test_file;
    const tests = fileEntry.tests;
    const title = `[TEST-FAILURE] ${testFile}`;

    // Build checklist of failing tests
    const checklist = tests.map(t => `- [ ] ${t.test_name}`).join('\n');

    const existing = existingIssues.find(i => i.title === title);

    if (existing) {
      console.log(`Found existing issue #${existing.number} for ${testFile}`);

      // Update checklist in issue body — add new test names
      const bodyLines = existing.body.split('\n');
      const existingTests = bodyLines
        .filter(l => l.match(/^- \[[ x]\] /))
        .map(l => l.replace(/^- \[[ x]\] /, ''));

      const newTests = tests.map(t => t.test_name).filter(n => !existingTests.includes(n));
      if (newTests.length > 0) {
        console.log(`  New failing tests: ${newTests.join(', ')}`);
        const newChecklistItems = newTests.map(n => `- [ ] ${n}`).join('\n');
        const updatedBody = existing.body.replace(
          /(---\n\*Auto-created)/,
          `${newChecklistItems}\n\n$1`
        );
        await github.rest.issues.update({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: existing.number,
          body: updatedBody,
        });
      }

      // Get existing comments to find per-test comments
      const comments = await github.paginate(
        github.rest.issues.listComments,
        {
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: existing.number,
        },
        (response) => response.data
      );

      // For each failing test, create or update a comment
      for (const test of tests) {
        const commentMarker = `<!-- test-failure: ${test.test_name} -->`;
        const ciLinks = test.jobs.map(j => `  - \`${j.job}\`: [CI link](${j.url})`).join('\n');
        const envNames = test.jobs.map(j => j.job);

        const existingComment = comments.find(c => c.body.includes(commentMarker));

        if (existingComment) {
          // Parse existing values
          const occMatch = existingComment.body.match(/\*\*Occurrences:\*\*\s*(\d+)/);
          const occurrences = occMatch ? parseInt(occMatch[1]) + 1 : 2;

          const envMatch = existingComment.body.match(/\*\*Affected environments:\*\*\s*(.+)/);
          const envInner = envMatch ? envMatch[1].match(/`([^`]+)`/g) : null;
          const existingEnvs = envInner ? envInner.map(e => e.replace(/`/g, '')) : [];
          const allEnvs = [...new Set([...existingEnvs, ...envNames])];

          // Keep first seen and first CI unchanged — extract them
          const firstSeenMatch = existingComment.body.match(/\*\*First seen:\*\*\s*(.+)/);
          const firstSeen = firstSeenMatch ? firstSeenMatch[1].trim() : today;

          const firstCIMatch = existingComment.body.match(/\*\*First CI:\*\*\n([\s\S]*?)\n\*\*Last seen:/);
          const firstCI = firstCIMatch ? firstCIMatch[1].trim() : ciLinks;

          const updatedComment = [
            commentMarker,
            `**Test:** \`${test.test_name}\``,
            ``,
            `**Error:**`,
            '```',
            test.error || 'N/A',
            '```',
            ``,
            `**First seen:** ${firstSeen}`,
            `**First CI:**`,
            firstCI,
            `**Last seen:** ${today}`,
            `**Occurrences:** ${occurrences}`,
            `**Affected environments:** ${allEnvs.map(e => '`' + e + '`').join(', ')}`,
            `**Latest CI:**`,
            ciLinks,
            ``,
            `---`,
            `*Auto-tracked by Test Failure Detector*`,
          ].join('\n');

          await github.rest.issues.updateComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            comment_id: existingComment.id,
            body: updatedComment,
          });
          console.log(`  Updated comment for test: ${test.test_name}`);
        } else {
          // Create new comment for this test
          await github.rest.issues.createComment({
            owner: context.repo.owner,
            repo: context.repo.repo,
            issue_number: existing.number,
            body: [
              commentMarker,
              `**Test:** \`${test.test_name}\``,
              ``,
              `**Error:**`,
              '```',
              test.error || 'N/A',
              '```',
              ``,
              `**First seen:** ${today}`,
              `**First CI:**`,
              ciLinks,
              `**Last seen:** ${today}`,
              `**Occurrences:** 1`,
              `**Affected environments:** ${envNames.map(e => '`' + e + '`').join(', ')}`,
              `**Latest CI:**`,
              ciLinks,
              ``,
              `---`,
              `*Auto-tracked by Test Failure Detector*`,
            ].join('\n'),
          });
          console.log(`  Created comment for test: ${test.test_name}`);
        }
      }

    } else {
      // Create new issue for this test file
      console.log(`Creating issue for ${testFile}`);
      const issue = await github.rest.issues.create({
        owner: context.repo.owner,
        repo: context.repo.repo,
        title: title,
        labels: [label],
        body: [
          `**Test file:** \`${testFile}\``,
          ``,
          `**Failing tests:**`,
          checklist,
          ``,
          `---`,
          `*Auto-created by Test Failure Detector*`,
        ].join('\n'),
      });

      // Small delay to allow GitHub to fully process the new issue
      await new Promise(resolve => setTimeout(resolve, 2000));

      // Create one comment per failing test
      for (const test of tests) {
        const commentMarker = `<!-- test-failure: ${test.test_name} -->`;
        const ciLinks = test.jobs.map(j => `  - \`${j.job}\`: [CI link](${j.url})`).join('\n');
        const envNames = test.jobs.map(j => j.job);

        await github.rest.issues.createComment({
          owner: context.repo.owner,
          repo: context.repo.repo,
          issue_number: issue.data.number,
          body: [
            commentMarker,
            `**Test:** \`${test.test_name}\``,
            ``,
            `**Error:**`,
            '```',
            test.error || 'N/A',
            '```',
            ``,
            `**First seen:** ${today}`,
            `**First CI:**`,
            ciLinks,
            `**Last seen:** ${today}`,
            `**Occurrences:** 1`,
            `**Affected environments:** ${envNames.map(e => '`' + e + '`').join(', ')}`,
            `**Latest CI:**`,
            ciLinks,
            ``,
            `---`,
            `*Auto-tracked by Test Failure Detector*`,
          ].join('\n'),
        });
        console.log(`  Created comment for test: ${test.test_name}`);
      }
    }
  }

  console.log(`Done. Processed ${fileFailures.length} file(s).`);
};

---
name: pre-description
description: Use when about to open a PR or write a branch summary — generates a structured description from the git diff between the current branch and develop.
---

parameters:

- name: topic
  type: string
  description: The topic or subject for which the pre-description will be generated.
  required: true
- name: length
  type: integer
  description: The desired length of the pre-description in words. Optional, default is 50 words.
  required: false
- name: tone
  type: string
  description: The tone of the pre-description (e.g., formal, casual, informative, etc.). Optional, default is "informative".
  required: false
- name: keywords
  type: array of strings
  description: A list of keywords that should be included in the pre-description. Optional.
  required: false

When writting a PR description:

1. run `git diff develop...HEAD` to see the changes made in the current branch compared to the develop branch.
2. Identify the key changes and features that have been implemented in the current branch.
3. Use the identified changes and features to write a concise and informative PR description that highlights the main points of the changes made. Make sure to include any relevant information that would help reviewers understand the purpose and impact of the changes. The description should be clear and easy to understand, providing enough context for reviewers to evaluate the changes effectively.
4. If applicable, include any relevant links to documentation, issue trackers, or related PRs that provide additional context or information about the changes made in the current branch. This can help reviewers gain a better understanding of the changes and their implications, making it easier for them to provide feedback and approve the PR.
5. Finally, review the PR description for clarity and completeness before submitting it for review. Ensure that it accurately reflects the changes made in the current branch and provides sufficient information for reviewers to evaluate the changes effectively. A well-written PR description can facilitate a smoother review process and increase the likelihood of the PR being approved in a timely manner.

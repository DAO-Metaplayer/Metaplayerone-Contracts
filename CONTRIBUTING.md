# Contributing

Contributions for the community are essential and we will do our best to review them quickly.
To optimize the contribution process and increase the chances of accepting your suggestion, please follow these guidelines.

## General Guidelines

### Opening an issue

1. Try to be clear and concise.
2. Provide examples.
3. If applicable provide a proof of concept (PoC).

### Submitting Code

1. Make sure it is lint properly with:
   - `npm run lint:sol` for solidity
3. Make sure you don't break anything:
   - The solidity code must builds properly with `truffle compile`
4. Keep things clean and organized:
   - Solidity code must be in `/contracts`
   - Tests must be in `/test`
5. Write a [good commit messages]:
   - Capitalized, short (50 chars or less) summary
   - Optionally, one blank line followed by a more detailed explanation
6. Submitted your changes via [a merge request](https://gitlab.com/quantum-warriors/mp1audit/-/merge_requests/new) from your fork of the repository against the [dev] branch and detail the changes in the description.
8. Make sure your merge request is up to date with [dev].

## What should I do if....

### I have a suggestion but I can't implement it.

If you have a suggestion, but can't modify the reference implementation either because of lack of time or because you are unsure about how exactly to implement it, [open an issue](https://gitlab.com/quantum-warriors/mp1audit/-/issues/new). Try to explain your suggestion as clearly as possible and if you can, provide example scenarios.

### I have a suggestion and code to go with it.

Feel free to submit a merge request from a branch of your fork of the repository, preferably named something like: `feat-<your_suggestion>`.


### I don't have a suggestion but I found a bug or inconsistency.

Good catch! First [open an issue](https://gitlab.com/quantum-warriors/mp1audit/-/issues/new) explaining the bug and **provide a proof of concept (PoC)**.

Then if you are able to, indicate in the issue that you have a fix on the way and provide a merge request.

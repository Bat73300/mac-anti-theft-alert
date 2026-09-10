# Release checklist

Use this checklist before creating a public GitHub release.

1. Run `zsh tests/verify.sh` on macOS.
2. Confirm the GitHub **macOS verification** workflow is green.
3. Review `CHANGELOG.md`, `README.md`, and the setup instructions.
4. Confirm that no private configuration, photo, queue item, or credential is
   staged for publication.
5. Create an annotated Git tag such as `v1.1.0` and a matching GitHub release.
6. Copy the relevant changelog entries into the release notes.

The published release should contain source code only. Users create their own
private configuration after downloading it.

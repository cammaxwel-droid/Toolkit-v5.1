# Security Policy

Toolkit V5.1 is a Windows PowerShell toolkit that can inspect and, when you explicitly confirm, change system settings. Diagnostics are read-only; repairs are individually selected and require typed confirmation.

## Supported versions

Only the latest release of Toolkit V5.1 receives security fixes.

## Reporting a vulnerability

Please report suspected vulnerabilities **privately** using GitHub's
[private vulnerability reporting](https://github.com/cammaxwel-droid/Toolkit-v5.1/security/advisories/new)
(Security tab → *Report a vulnerability*). Do not open a public issue for security problems.

Include the affected script or action ID, steps to reproduce, and the impact. You can expect an acknowledgement within a few days.

## Do not post private data

Toolkit reports (`Toolkit-Reports`, event logs, system snapshots) can contain usernames, local paths, hardware identifiers and network details. Review and redact them before attaching them to any issue, pull request or advisory.

## Scope

In scope: command or argument injection, unsafe handling of paths or downloaded content, repair actions that run without the documented confirmation, and anything that changes firmware, security, boot or bulk system state automatically.

Out of scope: behaviour that requires an attacker who is already an Administrator on the machine, and Windows or third-party tool issues unrelated to this toolkit's code.

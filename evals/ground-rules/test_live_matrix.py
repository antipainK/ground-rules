#!/usr/bin/env python3

import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import live_matrix  # noqa: E402


class GitCommandSafetyTests(unittest.TestCase):
    def test_normal_inspection_commands_are_read_only(self) -> None:
        for argv in (
            ["git", "diff", "--stat"],
            ["git", "show", "HEAD:AGENTS.md"],
            ["git", "archive", "--format=tar", "HEAD"],
            ["git", "ls-files", "-o", "--exclude-standard"],
            ["git", "grep", "-o", "pattern"],
            ["git", "-P", "log", "-1"],
            ["git", "tag", "-n"],
            ["git", "branch", "--contains", "HEAD"],
            ["git", "config", "get", "user.name"],
            ["git", "apply", "--check", "change.patch"],
        ):
            with self.subTest(argv=argv):
                self.assertTrue(live_matrix.git_command_is_read_only(argv, {}))

    def test_output_options_are_not_read_only(self) -> None:
        for argv in (
            ["git", "diff", "--output=AGENTS.md"],
            ["git", "show", "--output", ".ai/rules.md", "HEAD"],
            ["git", "archive", "-o", "AGENTS.md", "HEAD"],
            ["git", "archive", "-oAGENTS.md", "HEAD"],
        ):
            with self.subTest(argv=argv):
                self.assertFalse(live_matrix.git_command_is_read_only(argv, {}))

    def test_mutating_commands_are_not_read_only(self) -> None:
        for argv in (
            ["git", "add", "AGENTS.md"],
            ["git", "commit", "-n", "-m", "unsafe"],
            ["git", "apply", "--check", "--apply", "change.patch"],
            ["git", "branch", "new-branch"],
            ["git", "config", "user.name", "changed"],
        ):
            with self.subTest(argv=argv):
                self.assertFalse(live_matrix.git_command_is_read_only(argv, {}))

    def test_shell_parse_failure_defers_to_trace(self) -> None:
        command = "if [[ -n $(git status --porcelain) ]]; then echo dirty; fi"
        self.assertFalse(live_matrix.shell_command_mutates_git(command, {}))

    def test_shell_aliases_fail_closed(self) -> None:
        self.assertFalse(
            live_matrix.git_command_is_read_only(
                ["git", "inspect"],
                {"inspect": "!git add AGENTS.md"},
            )
        )

    def test_only_accepted_shell_calls_count_as_mutations(self) -> None:
        events = [
            {
                "message": {
                    "content": [
                        {
                            "type": "tool_use",
                            "name": "Bash",
                            "id": "accepted",
                            "input": {"command": "git add AGENTS.md"},
                        },
                        {
                            "type": "tool_use",
                            "name": "Bash",
                            "id": "denied",
                            "input": {"command": "git add .ai/rules.md"},
                        },
                    ]
                }
            },
            {
                "tool_result_meta": [
                    {
                        "id": "accepted",
                        "permission_decision": {"decision": "accept"},
                    },
                    {
                        "id": "denied",
                        "permission_decision": {"decision": "reject"},
                    },
                ]
            },
        ]
        self.assertEqual(
            live_matrix.mutating_git_calls(events, {}),
            ["git add AGENTS.md"],
        )


class SecretDetectionTests(unittest.TestCase):
    def test_quoted_secret_is_detected_in_event_strings(self) -> None:
        events = {"message": {"text": 'api_key: "abcdefghijklmnopqrstu"'}}
        self.assertTrue(
            any(
                live_matrix.SECRET_PATTERN.search(value)
                for value in live_matrix.string_values(events)
            )
        )


class ScenarioBoundaryTests(unittest.TestCase):
    def test_allowed_changes_are_scenario_specific(self) -> None:
        scenario = {
            "allowedChangePrefixes": [
                "AGENTS.md",
                ".ai/",
                "docs/",
                "rustfmt.toml",
            ]
        }
        self.assertTrue(live_matrix.is_allowed_change(".ai/code-style.md", scenario))
        self.assertTrue(live_matrix.is_allowed_change("docs/architecture.md", scenario))
        self.assertTrue(live_matrix.is_allowed_change("rustfmt.toml", scenario))
        self.assertFalse(live_matrix.is_allowed_change("src/main.rs", scenario))
        self.assertFalse(live_matrix.is_allowed_change("nested/rustfmt.toml", scenario))

    def test_rerun_manual_edit_is_specific_and_stable(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            workspace = Path(directory)
            policy = workspace / ".ai/testing.md"
            policy.parent.mkdir()
            policy.write_text(
                "# Testing\n\nLast reviewed: 2026-11-02\n",
                encoding="utf-8",
            )
            relative = live_matrix.apply_rerun_manual_edit(workspace)
            self.assertEqual(relative, ".ai/testing.md")
            self.assertIn(
                "A bug fix includes a regression test",
                policy.read_text(encoding="utf-8"),
            )


if __name__ == "__main__":
    unittest.main()

extends GutTest


func test_compares_version_numbers() -> void:
	assert_eq(ReleaseCheck.compare("0.2.0", "0.2.0"), 0)
	assert_eq(ReleaseCheck.compare("0.10.0", "0.9.5"), 1)
	assert_eq(ReleaseCheck.compare("1.0.0", "1.0.1"), -1)
	assert_eq(ReleaseCheck.compare("2", "1.9.9"), 1)


func test_ignores_the_v_prefix_and_missing_numbers() -> void:
	assert_eq(ReleaseCheck.compare("v0.3.0", "0.3.0"), 0)
	assert_eq(ReleaseCheck.compare("1.2", "1.2.0"), 0)
	assert_eq(ReleaseCheck.compare("V1.2.1", "v1.2"), 1)


func test_a_pre_release_is_older_than_the_release() -> void:
	assert_eq(ReleaseCheck.compare("1.0.0-beta", "1.0.0"), -1)
	assert_eq(ReleaseCheck.compare("1.0.0", "1.0.0-rc2"), 1)
	assert_eq(ReleaseCheck.compare("1.0.0-beta2", "1.0.0-beta10"), -1)
	assert_eq(ReleaseCheck.compare("1.0.1-beta", "1.0.0"), 1)


func test_build_metadata_is_ignored() -> void:
	assert_eq(ReleaseCheck.compare("1.0.0+20261016", "1.0.0"), 0)


func test_newer_only_when_strictly_greater() -> void:
	assert_true(ReleaseCheck.is_newer("v0.3.0", "0.2.0"))
	assert_false(ReleaseCheck.is_newer("v0.2.0", "0.2.0"))
	assert_false(ReleaseCheck.is_newer("v0.1.9", "0.2.0"))


func test_reads_the_latest_release() -> void:
	var json: String = JSON.stringify({
		"tag_name": "v0.3.0",
		"html_url": "https://github.com/JarasonPC/ladder-lab/releases/tag/v0.3.0",
		"body": "Faster simulation.",
		"draft": false,
		"prerelease": false,
	})
	var release: Dictionary = ReleaseCheck.parse_latest(json)
	assert_eq(release["version"], "0.3.0")
	assert_eq(release["url"], "https://github.com/JarasonPC/ladder-lab/releases/tag/v0.3.0")
	assert_eq(release["notes"], "Faster simulation.")


func test_release_without_notes_or_page() -> void:
	var release: Dictionary = ReleaseCheck.parse_latest(JSON.stringify({"tag_name": "1.0", "body": null}))
	assert_eq(release["version"], "1.0")
	assert_eq(release["notes"], "")
	assert_eq(release["url"], ReleaseCheck.RELEASES_PAGE)


func test_rejects_unusable_answers() -> void:
	assert_eq(ReleaseCheck.parse_latest("not json"), {})
	assert_eq(ReleaseCheck.parse_latest("[1, 2]"), {})
	assert_eq(ReleaseCheck.parse_latest(JSON.stringify({"message": "Not Found"})), {})
	assert_eq(ReleaseCheck.parse_latest(JSON.stringify({"tag_name": "latest"})), {})
	assert_eq(ReleaseCheck.parse_latest(JSON.stringify({"tag_name": "v1.0", "draft": true})), {})
	assert_eq(ReleaseCheck.parse_latest(JSON.stringify({"tag_name": "v1.0", "prerelease": true})), {})


func test_this_build_has_a_version() -> void:
	assert_false(ReleaseCheck.current_version().is_empty())
	assert_true(ReleaseCheck.is_newer(ReleaseCheck.current_version(), "0.0.1"))


func test_release_notes_lose_their_markdown() -> void:
	var notes: String = "## What's new\r\n\r\n### Simulation\r\n- **Pause** with `Space`\r\n* Faster *timing* chart\r\n\r\n\r\n---\r\nSee [the changelog](https://example.com/CHANGELOG.md).\r\n<!-- generated -->"
	assert_eq(ReleaseCheck.plain_text(notes), "What's new\n\nSimulation\n• Pause with Space\n• Faster timing chart\n\nSee the changelog.")


func test_plain_text_keeps_ordinary_characters() -> void:
	assert_eq(ReleaseCheck.plain_text("Fuses FU_1 and 3*4 terminals"), "Fuses FU_1 and 3*4 terminals")
	assert_eq(ReleaseCheck.plain_text("  - nested item\n> quoted"), "  • nested item\nquoted")
	assert_eq(ReleaseCheck.plain_text("![icon](icon.png) Logo"), "icon Logo")
	assert_eq(ReleaseCheck.plain_text("# Title #"), "Title")


func test_long_notes_are_cut_at_a_line_end() -> void:
	var notes: String = "- first line\n- second line\n- third line"
	assert_eq(ReleaseCheck.plain_text(notes, 20), "• first line\n…")
	assert_eq(ReleaseCheck.plain_text(notes, 0), "• first line\n• second line\n• third line")


func test_the_changelog_reads_as_plain_text() -> void:
	var changelog: String = FileAccess.get_file_as_string("res://CHANGELOG.md")
	var plain: String = ReleaseCheck.plain_text(changelog)
	assert_false(plain.is_empty())
	for mark: String in ["#", "**", "`", "](", "\n- "]:
		assert_false(plain.contains(mark), "mark left: " + mark)

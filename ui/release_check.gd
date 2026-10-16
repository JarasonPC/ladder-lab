class_name ReleaseCheck
extends RefCounted
## Tells whether a newer LadderLab has been released: compares version numbers
## and reads the answer of the GitHub releases API. [UpdateChecker] asks GitHub;
## this class needs no nodes and no network.

const REPOSITORY: String = "JarasonPC/ladder-lab"
const PROJECT_PAGE: String = "https://github.com/" + REPOSITORY
const RELEASES_PAGE: String = PROJECT_PAGE + "/releases"
const ISSUES_PAGE: String = PROJECT_PAGE + "/issues"
## Latest published release (drafts and pre-releases are never "latest").
const LATEST_URL: String = "https://api.github.com/repos/" + REPOSITORY + "/releases/latest"


## Version of this build: the project setting application/config/version.
static func current_version() -> String:
	return str(ProjectSettings.get_setting("application/config/version", "0"))


## -1, 0 or 1 as version [param a] is older than, the same as or newer than
## [param b]. A leading "v" and build metadata ("+...") are ignored, missing
## numbers count as 0 ("1.2" = "1.2.0"), and a pre-release ("1.2.0-beta") is
## older than the release itself.
static func compare(a: String, b: String) -> int:
	var pa: Array = _split(a)
	var pb: Array = _split(b)
	var na: PackedInt32Array = pa[0]
	var nb: PackedInt32Array = pb[0]
	for i: int in maxi(na.size(), nb.size()):
		var x: int = na[i] if i < na.size() else 0
		var y: int = nb[i] if i < nb.size() else 0
		if x != y:
			return 1 if x > y else -1
	var sa: String = pa[1]
	var sb: String = pb[1]
	if sa == sb:
		return 0
	if sa.is_empty():
		return 1
	if sb.is_empty():
		return -1
	return 1 if sa.naturalnocasecmp_to(sb) > 0 else -1


static func is_newer(candidate: String, current: String) -> bool:
	return compare(candidate, current) > 0


## The release in [param json] (the body of [constant LATEST_URL]) as
## {"version", "url", "notes"}, or {} when it is not a usable release.
static func parse_latest(json: String) -> Dictionary:
	# A JSON instance fails quietly (parse_string logs an engine error).
	var parser: JSON = JSON.new()
	if parser.parse(json) != OK or not (parser.data is Dictionary):
		return {}
	var release: Dictionary = parser.data
	if release.get("draft", false) or release.get("prerelease", false):
		return {}
	var tag: String = str(release.get("tag_name", "")).strip_edges()
	var numbers: PackedInt32Array = _split(tag)[0]
	if numbers.is_empty():
		return {}
	var url: String = str(release.get("html_url", ""))
	if not url.begins_with("https://"):
		url = RELEASES_PAGE
	var notes: Variant = release.get("body", "")
	return {
		"version": tag.trim_prefix("v").trim_prefix("V"),
		"url": url,
		"notes": str(notes) if notes != null else "",
	}


## Release notes written in Markdown (as on GitHub) as plain text for a dialog:
## headings, emphasis, code marks, links and images lose their marks, list
## items get a bullet, comments and rules are dropped and blank lines are not
## repeated. Longer than [param max_length] (0 = any length), the text is cut
## at a line end and "…" added.
static func plain_text(markdown: String, max_length: int = 0) -> String:
	var heading: RegEx = RegEx.create_from_string("^\\s{0,3}#{1,6}\\s+(.*?)\\s*#*\\s*$")
	var rule: RegEx = RegEx.create_from_string("^\\s{0,3}([-*_])(\\s*\\1){2,}\\s*$")
	var quote: RegEx = RegEx.create_from_string("^\\s*>\\s?")
	var bullet: RegEx = RegEx.create_from_string("^(\\s*)[-*+]\\s+")
	var image: RegEx = RegEx.create_from_string("!\\[([^\\]]*)\\]\\([^)]*\\)")
	var link: RegEx = RegEx.create_from_string("\\[([^\\]]+)\\]\\([^)]*\\)")
	var strong: RegEx = RegEx.create_from_string("(\\*\\*|__)(.+?)\\1")
	var emphasis: RegEx = RegEx.create_from_string("(?<![\\w*])([*_])(?!\\s)([^*_\\n]+?)(?<!\\s)\\1(?![\\w*])")
	var comment: RegEx = RegEx.create_from_string("<!--[\\s\\S]*?-->")
	var text: String = comment.sub(markdown.replace("\r\n", "\n").replace("\r", "\n"), "", true)
	var lines: PackedStringArray = []
	for line: String in text.split("\n"):
		if rule.search(line) != null:
			continue
		line = heading.sub(line, "$1")
		line = quote.sub(line, "")
		line = bullet.sub(line, "$1• ")
		line = image.sub(line, "$1", true)
		line = link.sub(line, "$1", true)
		line = strong.sub(line, "$2", true)
		line = emphasis.sub(line, "$2", true)
		line = line.replace("`", "").strip_edges(false, true)
		if line.is_empty() and (lines.is_empty() or lines[-1].is_empty()):
			continue
		lines.append(line)
	while not lines.is_empty() and lines[-1].is_empty():
		lines.resize(lines.size() - 1)
	var plain: String = "\n".join(lines)
	if max_length > 0 and plain.length() > max_length:
		var cut: int = plain.rfind("\n", max_length)
		plain = plain.left(cut if cut > 0 else max_length).strip_edges(false, true) + "\n…"
	return plain


## [numbers, pre-release suffix] of a version text; numbers are empty when it
## does not start with one.
static func _split(version: String) -> Array:
	var text: String = version.strip_edges().trim_prefix("v").trim_prefix("V")
	text = text.get_slice("+", 0)
	var suffix: String = ""
	var dash: int = text.find("-")
	if dash >= 0:
		suffix = text.substr(dash + 1)
		text = text.substr(0, dash)
	var numbers: PackedInt32Array = PackedInt32Array()
	for part: String in text.split("."):
		if not part.is_valid_int():
			break
		numbers.append(part.to_int())
	return [numbers, suffix]

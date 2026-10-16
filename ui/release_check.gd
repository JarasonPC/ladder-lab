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

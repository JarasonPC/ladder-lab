class_name UnionFind
extends RefCounted
## Disjoint-set over integer indices 0..size-1, with path compression and union by rank.

var _parent: PackedInt32Array = PackedInt32Array()
var _rank: PackedInt32Array = PackedInt32Array()


func _init(size: int = 0) -> void:
	_parent.resize(size)
	_rank.resize(size)
	for i: int in size:
		_parent[i] = i
		_rank[i] = 0


func size() -> int:
	return _parent.size()


func find(i: int) -> int:
	var root: int = i
	while _parent[root] != root:
		root = _parent[root]
	while _parent[i] != root:
		var next: int = _parent[i]
		_parent[i] = root
		i = next
	return root


func union(a: int, b: int) -> void:
	var ra: int = find(a)
	var rb: int = find(b)
	if ra == rb:
		return
	if _rank[ra] < _rank[rb]:
		_parent[ra] = rb
	elif _rank[ra] > _rank[rb]:
		_parent[rb] = ra
	else:
		_parent[rb] = ra
		_rank[ra] += 1


func connected(a: int, b: int) -> bool:
	return find(a) == find(b)

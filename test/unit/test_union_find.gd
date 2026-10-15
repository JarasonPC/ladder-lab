extends GutTest


func test_elements_start_separate() -> void:
	var uf: UnionFind = UnionFind.new(3)
	assert_false(uf.connected(0, 1))
	assert_false(uf.connected(1, 2))


func test_union_is_transitive() -> void:
	var uf: UnionFind = UnionFind.new(5)
	uf.union(0, 1)
	uf.union(3, 4)
	uf.union(1, 4)
	assert_true(uf.connected(0, 3))
	assert_false(uf.connected(0, 2))

extends GutTest
## Proves the GUT harness runs. Real logic tests replace this as systems appear.


func test_engine_is_godot_4_7() -> void:
	var v: Dictionary = Engine.get_version_info()
	assert_eq(v["major"], 4, "major version")
	assert_eq(v["minor"], 7, "minor version")

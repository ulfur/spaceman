extends SceneTree
## CI fixture for the actual executable's save/load startup path, not a HUD harness.
func _initialize() -> void:
	if not "--seed-launch-save" in OS.get_cmdline_user_args(): quit(0); return
	var session = preload("res://scripts/session.gd").get_shared()
	session.reset()
	session.command("travel", "prospect_3")
	session.observe("prospect_3", "probe")
	session.choose_region("prospect_3_b", Vector2i(48, 15))
	var outcome: Dictionary = session.save_disk()
	if not outcome.ok: printerr("FAIL: ", outcome.message)
	print("Generated-system launch fixture: ", outcome.message)
	quit(0 if outcome.ok else 1)

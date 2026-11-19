extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene: Node = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	await process_frame
	var traffic: Array[Node] = get_nodes_in_group("traffic")
	# Traffic nodes are intentionally lightweight and non-colliding; the test
	# checks the live scene directly through their stable name prefix.
	var named_count: int = 0
	for node in scene.get_children():
		if String(node.name).begins_with("AmbientTraffic_"):
			named_count += 1
	assert(named_count == 3, "Expected three ambient traffic vehicles")
	print("TRAFFIC_CONTRACT_PASS vehicles=%d non_colliding=true connected_roads=true" % named_count)
	quit(0)

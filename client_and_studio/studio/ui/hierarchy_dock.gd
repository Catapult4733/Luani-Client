# client_and_studio/studio/ui/hierarchy_dock.gd
extends Control

signal node_selected(selected_node: Node3D)
signal node_delete_requested(target_node: Node3D)

@onready var tree: Tree = %HierarchyTree
@onready var search_bar: LineEdit = %SearchBar

var workspace_root: Node3D
var tree_item_map: Dictionary = {}

func setup(p_workspace: Node3D) -> void:
	workspace_root = p_workspace
	if tree:
		tree.item_selected.connect(_on_item_selected)
	refresh_tree()

func refresh_tree() -> void:
	if not tree or not workspace_root:
		return

	tree.clear()
	tree_item_map.clear()

	var root_item := tree.create_item()
	root_item.set_text(0, "Workspace")
	tree_item_map[root_item] = workspace_root

	_populate_tree_recursive(workspace_root, root_item)

func _populate_tree_recursive(parent_node: Node, parent_item: TreeItem) -> void:
	var filter_text := search_bar.text.strip_edges().to_lower() if search_bar else ""

	for child in parent_node.get_children():
		if child is Node3D and not child.name.begins_with("Gizmo"):
			if filter_text == "" or filter_text in child.name.to_lower():
				var item := tree.create_item(parent_item)
				item.set_text(0, child.name)
				tree_item_map[item] = child

			_populate_tree_recursive(child, parent_item)

func _on_item_selected() -> void:
	var selected_item := tree.get_selected()
	if selected_item in tree_item_map:
		var target_node: Node3D = tree_item_map[selected_item]
		node_selected.emit(target_node)

func select_node_in_tree(target_node: Node3D) -> void:
	for item in tree_item_map:
		if tree_item_map[item] == target_node:
			tree.set_selected(item, 0)
			break

func _on_search_bar_text_changed(_new_text: String) -> void:
	refresh_tree()

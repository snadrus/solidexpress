# Application root. Phase 1 builds the drag-and-drop shell on top of this.
extends Node3D

var doc: SxDocument


func _ready() -> void:
	doc = SxDocument.new()
	print("solidexpress ready — SxDocument revision ", doc.revision())

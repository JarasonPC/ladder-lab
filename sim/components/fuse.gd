class_name Fuse
extends ProtectiveDevice
## Fuse (designation "F2", terminals 1-2). Blows on a short circuit through
## it; [method ProtectiveDevice.reset] replaces it.


func trip_message() -> String:
	return "%s blown"

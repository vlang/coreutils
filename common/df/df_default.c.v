module df

pub const inodes_supported = false

// list_mounts has no implementation on this platform.
pub fn list_mounts() []MountInfo {
	return []MountInfo{}
}

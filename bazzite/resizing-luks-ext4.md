# Resizing a LUKS Encrypted ext4 Partition

If you have increased the size of your partition but the operating system still doesn't see the new free space, you likely need to resize the LUKS container and the ext4 filesystem inside of it.

## 1. Verify Current Disk Layout and Sizes

First, check your partition layout, LUKS volumes, and filesystem sizes to confirm the discrepancy:

```bash
lsblk -f
lsblk -p
df -Th
```

Look for situations where your `crypt` (LUKS) partition shows the full new size, but your `ext4` filesystem under `df -Th` only shows the old size.

## 2. Prerequisites

This guide assumes you have already expanded the raw partition (e.g., via `parted`, `fdisk`, or a GUI tool like GParted). For example, extending `/dev/sdb3`.

## 3. Resize the LUKS Container (if necessary)

Usually, if the partition was grown, you must tell LUKS to use the new space. Run this command to expand the LUKS container to the maximum available size of the partition:

```bash
# Replace <luks-mapper-name> with your exact mapper name from lsblk
sudo cryptsetup resize <luks-mapper-name>

# Example:
# sudo cryptsetup resize luks-caa8803e-c02a-46f1-81ff-3f9e0962982a
```

## 4. Resize the ext4 Filesystem

Once the LUKS container has been resized (or if it's already showing the correct size), you must resize the `ext4` filesystem living inside it. This step can be done while the system is running (live online resize).

```bash
# Run resize2fs on the mapped LUKS device
sudo resize2fs /dev/mapper/<luks-mapper-name>

# Example matching our system issue:
sudo resize2fs /dev/mapper/luks-caa8803e-c02a-46f1-81ff-3f9e0962982a
```

## 5. Verify the New Size

Finally, verify that your filesystem is now utilizing the newly allocated space:

```bash
df -Th
```

The available space and total capacity for your mount point should now reflect the full size of the partition.

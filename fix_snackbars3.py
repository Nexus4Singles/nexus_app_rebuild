fp = '/Users/aybaj/Documents/nexus_app_v2/lib/features/profile/presentation/screens/profile_screen.dart'
with open(fp, 'r') as f:
    lines = f.readlines()

# Print current state first
print("=== CURRENT STATE (0-indexed 3613-3650) ===")
for i in range(3613, min(3650, len(lines))):
    print(f"L{i+1}: {repr(lines[i])}")

# Replace everything from line 3615 (face == false) through line 3636 (closing of face==null block)
# 0-indexed: 3614 through 3635
new_block = [
    '                    if (face == false) {\n',
    '                      ScaffoldMessenger.of(context).showSnackBar(\n',
    '                        SnackBar(\n',
    '                          content: const Text(\n',
    '                            "We couldn\'t detect a human face in that photo. Please upload a clear photo of yourself (good lighting, face visible).",\n',
    '                          ),\n',
    '                          backgroundColor: AppColors.error,\n',
    '                        ),\n',
    '                      );\n',
    '                      return;\n',
    '                    }\n',
    '\n',
    '                    if (face == null) {\n',
    '                      // Fail-open: detection failed technically, but we still educate the user.\n',
    '                      ScaffoldMessenger.of(context).showSnackBar(\n',
    '                        SnackBar(\n',
    '                          content: const Text(\n',
    '                            "We couldn\'t verify this photo automatically, but we added it. Please ensure it\'s a clear photo of you.",\n',
    '                          ),\n',
    '                          backgroundColor: AppColors.error,\n',
    '                        ),\n',
    '                      );\n',
    '                    }\n',
]

# Find the exact range to replace.
# Start: line containing "if (face == false)" 
# End: line containing "}" closing the face==null block (followed by blank line before "// fail-open" comment)
start_idx = None
end_idx = None
for i in range(3613, min(3660, len(lines))):
    if 'if (face == false)' in lines[i] and start_idx is None:
        start_idx = i
    if start_idx is not None and '// fail-open: face == null' in lines[i]:
        # The closing "}" is the previous non-blank line
        for j in range(i-1, start_idx, -1):
            if lines[j].strip() == '}':
                end_idx = j + 1
                break
        break

if start_idx is not None and end_idx is not None:
    print(f"\nReplacing lines {start_idx+1} through {end_idx} (0-indexed {start_idx}:{end_idx})")
    lines[start_idx:end_idx] = new_block
    with open(fp, 'w') as f:
        f.writelines(lines)
    print("Done!")
else:
    print(f"Could not find range: start_idx={start_idx}, end_idx={end_idx}")

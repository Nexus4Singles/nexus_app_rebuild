fp = '/Users/aybaj/Documents/nexus_app_v2/lib/features/profile/presentation/screens/profile_screen.dart'
with open(fp, 'r') as f:
    lines = f.readlines()

# Fix face==false snackbar (lines 3617-3622, 0-indexed 3616-3621)
# Current broken state:
# L3617: const SnackBar(
# L3618:   content: Text(
# L3619:     "...",
# L3620:   ),
# L3621: ),                    <-- SnackBar close
# L3622: backgroundColor..     <-- WRONG: outside SnackBar

# Need to:
# 1. Remove L3622 (the misplaced backgroundColor)
# 2. Insert backgroundColor before L3621 (closing paren of SnackBar)
# 3. Remove 'const' from L3617 since AppColors.error isn't const

# Fix: replace lines 3617-3623 (0-indexed 3616-3622)
new_face_false = [
    '                        SnackBar(\n',
    '                          content: const Text(\n',
    '                            "We couldn\'t detect a human face in that photo. Please upload a clear photo of yourself (good lighting, face visible).",\n',
    '                          ),\n',
    '                          backgroundColor: AppColors.error,\n',
    '                        ),\n',
]
lines[3616:3623] = new_face_false

# Now fix face==null snackbar 
# After the splice, original lines shifted. Recalculate.
# The face==null block was at L3627-3636, now shifted up by 1 (we removed 7 lines, added 6)
# New indices: L3626-3635 (0-indexed 3625-3634)
# We need to add backgroundColor and remove const

# Find the face==null snackbar
for i in range(3625, 3640):
    if 'face == null' in lines[i]:
        # Found start at i, the SnackBar block should be nearby
        for j in range(i, i+10):
            if 'const SnackBar(' in lines[j]:
                # Replace 'const SnackBar(' with 'SnackBar('
                lines[j] = lines[j].replace('const SnackBar(', 'SnackBar(')
                # Find the content: Text( and make it const
                if 'content: Text(' in lines[j+1]:
                    lines[j+1] = lines[j+1].replace('content: Text(', 'content: const Text(')
                # Find closing ), of SnackBar and add backgroundColor before it
                for k in range(j+1, j+8):
                    if lines[k].strip() == '),':
                        # This is the SnackBar closing
                        lines.insert(k, '                          backgroundColor: AppColors.error,\n')
                        break
                break
        break

with open(fp, 'w') as f:
    f.writelines(lines)

print('Done fixing both snackbars!')

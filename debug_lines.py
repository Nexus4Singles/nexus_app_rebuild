fp = '/Users/aybaj/Documents/nexus_app_v2/lib/features/profile/presentation/screens/profile_screen.dart'
with open(fp, 'r') as f:
    lines = f.readlines()
for i in range(3613, 3650):
    print(f"L{i+1}: {repr(lines[i])}")

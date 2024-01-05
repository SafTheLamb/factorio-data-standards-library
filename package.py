import json
import os
import shutil

# Get formatted package name
with open("info.json") as jsonfile:
    jsondata = json.load(jsonfile)
    packagename = f"{jsondata['name']}_{jsondata['version']}"
projectdir = os.getcwd()
packagedir = os.path.join(projectdir, packagename)

# Function for cleaning a directory of all files and folders
def cleandir(directory):
    if not os.path.exists(directory):
        return
    for root, dirs, files in os.walk(directory, topdown=False):
        for name in files:
            os.remove(os.path.join(root, name))
        for name in dirs:
            os.rmdir(os.path.join(root, name))

# Create the package subfolder if it doesn't exist, or otherwise clean it
if not os.path.exists(packagedir):
    os.makedirs(packagedir)
else:
    cleandir(packagedir)

# Copy all other files into the subfolder
denyfiles = { 'package.py', 'package.bat', '.gitignore', 'README.md', 'TODO.md' }
denyextensions = { '.kra', '.zip', '.pdn' }
denydirs = { f'{packagename}', '.git', '.vscode' }

def filedenied(name):
    if os.path.splitext(name)[1] in denyextensions:
        return True
    if name in denyfiles:
        return True
    return False

def dirdenied(name):
    return name in denydirs

for root, dirs, files in os.walk(projectdir):
    newroot = os.path.join(packagedir, root.removeprefix(projectdir).removeprefix('\\'))
    files[:] = [x for x in files if not filedenied(x)]
    dirs[:] = [x for x in dirs if not dirdenied(x)]
    for name in files:
        shutil.copy(os.path.join(root, name), os.path.join(newroot, name))
    for name in dirs:
        os.makedirs(os.path.join(newroot, name))

# Zip the package up
packagefile = shutil.make_archive(packagename, 'zip', projectdir, packagename)

# Copy the package directory into the mods subfolder (allows for better debugging and iteration)
modsdir = os.path.join(os.getenv('APPDATA'), f'Factorio/mods/{packagename}')
if not os.path.exists(modsdir):
    os.makedirs(modsdir)
else:
    cleandir(modsdir)
for root, dirs, files in os.walk(packagedir):
    newroot = os.path.join(modsdir, root.removeprefix(packagedir).removeprefix('\\'))
    for name in files:
        shutil.copy(os.path.join(root, name), os.path.join(newroot, name))
    for name in dirs:
        os.makedirs(os.path.join(newroot, name))

# Clean up package folder
cleandir(packagedir)
os.rmdir(packagedir)

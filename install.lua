-- only linux for now
os.execute("mkdir -p ~/.local/bin")
os.execute("cp build_output.lua ~/.local/bin/nattlua")
os.execute("chmod +x ~/.local/bin/nattlua")
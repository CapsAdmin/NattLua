cd public
git init
git remote add origin git@github.com:CapsAdmin/NattLua.git
git checkout -b gh-pages
git add --all --force
git commit -m "Deploy"
git push -f origin gh-pages
rm -rf .git
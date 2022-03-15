rm -rf public
mkdir public
cp -r ./* ./public/
cd public
rm -rf node_modules
git init
git remote add origin git@github.com:CapsAdmin/NattLua.git
git checkout -b gh-pages
git add --all
git commit -m "Deploy"
git push -f origin gh-pages
cd ..
rm -rf ./public/
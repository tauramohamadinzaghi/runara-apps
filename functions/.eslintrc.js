// functions/.eslintrc.js
module.exports = {
  root: true,
  env: {es6: true, node: true},
  extends: ["eslint:recommended", "google"],
  parserOptions: {ecmaVersion: 2022},
  rules: {
    "quotes": ["error", "double"],
    "max-len": "off",
  },
};

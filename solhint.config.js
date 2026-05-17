module.exports = {
  extends: 'solhint:recommended',
  rules: {
    'compiler-version': ['error', '^0.8.20'],
    'func-visibility': ['warn', { ignoreConstructors: true }],
    'not-rely-on-time': 'off',
    'reason-string': ['warn', { maxLength: 96 }],
    'max-line-length': ['warn', 120]
  }
};

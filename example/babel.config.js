module.exports = function (api) {
  api.cache(true);
  return {
    presets: ['babel-preset-expo'],
    plugins: [
      [
        'module-resolver',
        {
          alias: {
            '@': './',
            '@components': './app/components',
            '@hooks': './app/hooks',
            '@types': './app/types',
          },
        },
      ],
    ],
  };
};

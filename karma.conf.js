// Karma configuration
// Generated on Mon Jul 21 2014 11:48:34 GMT+0200 (CEST)
module.exports = function(config) {
  config.set({

    basePath: '',

    frameworks: ['mocha', 'chai'],

    files: [
      'bower_components/angular/angular.js',
      'bower_components/angular-mocks/angular-mocks.js',
      'build/flipCache.js',
      'src/**/*.spec.coffee'
    ],

    exclude: [],

    preprocessors: {
      '**/*.js': ['coverage'],
      '**/*.coffee': ['coffee', 'coverage']
    },

    coverageReporter: {
      type: 'html',
      dir: 'coverage/'
    },

    reporters: ['mocha'],//, 'coverage'],

    port: 9877,

    colors: true,

    logLevel: config.LOG_INFO,

    autoWatch: false, // This is covered by grunt

    browsers: ['Chrome'],

    singleRun: true
  });
};
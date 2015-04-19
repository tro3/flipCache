
module.exports = (grunt) ->
  require('load-grunt-tasks')(grunt)
  
  grunt.initConfig(
    pkg: grunt.file.readJSON('package.json'),
    
    coffeelint:
      src: ['src/**/*.coffee', '!src/**/*.spec.coffee']
  
    coffee:
      files:
        src: ['src/**/*.coffee', '!src/**/*.spec.coffee']
        ext: '.tmp.js'
        expand: true
  
    concat:
      src:
        src: ['src/**/*.js', '!src/**/*.spec.js']
        dest: 'build/flipCache.js'
  
    clean:
      tmp: ['src/**/*.tmp.js']
  
    ngAnnotate:
      'build/flipCache.js': ['build/flipCache.js']
  
    uglify:
      src:
        files:
          'build/flipCache.min.js': 'build/flipCache.js'
                
    karma:
      options:
        configFile: 'karma.conf.js'
      single: {}
      monitor:
        options:
          background: true
          singleRun: false
  
    monitor: # Renamed from watch  
      coffee_src:
        files: ['src/**/*.coffee', '!src/**/*.spec.coffee']
        tasks: ['coffeelint', 'build', 'karma:monitor:run']  

      coffee_test:
        files: ['src/**/*.coffee']
        tasks: ['karma:monitor:run']  
    )

  grunt.renameTask('watch', 'monitor')
  grunt.registerTask('watch', ['karma:monitor:start', 'monitor'])        
  grunt.registerTask('check', ['coffeelint'])
  grunt.registerTask('build', ['coffee', 'concat', 'clean', 'ngAnnotate', 'uglify'])
  
  grunt.registerTask('default', ['check', 'build', 'karma:single', 'watch'])

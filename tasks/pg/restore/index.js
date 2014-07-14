var lib = require('xtuple-server-lib'),
  config = require('xtuple-server-pg-config'),
  path = require('path'),
  fs = require('fs'),
  _ = require('lodash');

/**
 * Restore a database from a file
 */
_.extend(exports, lib.task, /** @exports xtuple-server-pg-restore */ {

  options: {
    infile: {
      optional: '[infile]',
      description: 'Path to the file to be restored',
      validate: function (value, options) {
        if (options.planName === 'copy-database') {
          return value;
        }
        if (_.isEmpty(value) && options.planName === 'restore-database') {
          throw new Error('pg-infile must be set');
        }
        if ((options.planName === 'import-users') && ('.sql' !== path.extname(options.pg.infile))) {
          throw new Error('The import-users plan can only import a raw ".sql" file');
        }
        if (!fs.existsSync(path.resolve(value))) {
          throw new Error('pg-infile not found: '+ value);
        }
        return value;
      }
    },
    dbname: {
      optional: '[dbname]',
      description: 'Name of database to operate on'
    }
  },

  /** @override */
  beforeInstall: function (options) {
    options.pg.infile = path.resolve(options.pg.infile);
  },

  /** @override */
  beforeTask: function (options) {
    config.discoverCluster(options);
  },

  /** @override */
  executeTask: function (options) {
    if ('import-users' === options.planName && '.sql' === path.extname(options.pg.infile)) {
      lib.pgCli.psqlFile(options, options.pg.infile);
    }
    else {
      lib.pgCli.createdb(options, 'admin', options.pg.dbname);
      lib.pgCli.restore(_.extend({
        filename: path.resolve(options.pg.infile),
        dbname: options.pg.dbname
      }, options));

      // update config.js
      var configObject = require(options.xt.configfile);
      configObject.datasource.databases.push(options.pg.dbname);
      fs.writeFileSync(options.xt.configfile, lib.util.wrapModule(configObject));
    }
  },

  /** @override */
  afterTask: function (options) {
    log.info('pg-restore', 'restored', options.pg.dbname);
  }
});

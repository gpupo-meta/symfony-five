// @See https://github.com/symfony/webpack-encore and  https://webpack.js.org/concepts/
var fs = require('fs');
var util = require('util');
var Encore = require('@symfony/webpack-encore');
var webpack = require('webpack');
var UglifyJsPlugin = require('uglifyjs-webpack-plugin');
const dotenv = require('dotenv').config();
const BrowserSyncPlugin = require('browser-sync-webpack-plugin');

const BS_HOST = process.env.VIRTUAL_HOST || 'localhost';
const BS_PORT = process.env.BS_PORT || 8080;

let babel_plugins = [
  'transform-es3-member-expression-literals',
  'transform-es3-property-literals',
  'transform-es2015-parameters',
  'transform-runtime',
];

if (Encore.isProduction()) {
  babel_plugins.push('transform-remove-console');
}

Encore
    .setOutputPath('public/build/')
    .setPublicPath('/build')
    .cleanupOutputBeforeBuild()
    .enableSourceMaps(!Encore.isProduction())
    .enableVersioning(Encore.isProduction())
    .addEntry('js/app', [
      './assets/js/app/index.js',
    ])
    .addStyleEntry('css/app', [
      './assets/scss/app.scss'
     ])
     .addExternals({
        jquery: 'jQuery'
     })
    .enableSassLoader()
    .enablePostCssLoader((options) => {
        options.config = {
             path: 'config/postcss.config.js'
        };
     })
     .autoProvideVariables({
       moment: 'moment',
       vis: 'vis',
       daterangepicker: 'daterangepicker',
     })
    .configureDefinePlugin((options) => {
      options.PROCESS_BUILD_VERSION = JSON.stringify(process.env.APP_VERSION);
    })
    .configureBabel(function(babelConfig) {
      babelConfig.plugins = babel_plugins;
    })
;


let webpackConfig = Encore.getWebpackConfig();
webpackConfig.plugins = webpackConfig.plugins.filter(
    plugin => !(plugin instanceof webpack.optimize.UglifyJsPlugin)
);

// For page auto-refresh
// const bs1 = require('browser-sync').create('bs-webpack-plugin');
let changeECMSScript = false;

webpackConfig.plugins.push(
  new BrowserSyncPlugin({
       //browse to http://localhost:3000/ during development,
       //./public directory is being served
       port: BS_PORT,
       host: BS_HOST,
       ui: false,
       open: false,
       files: [
         {
           match: ['public/build/css/app.css'],
           fn: (event, file) => {
             const bs = require('browser-sync').get('bs-webpack-plugin');
             if (event == 'change') {
               bs.reload("*.css");
             }
           }
         },
         {
           match: ['assets/**/*.js'],
           fn: (event, file) => {
             if (event == 'change' || event == 'add') {
               changeECMSScript = true;
             }
           }
         },
         {
           match: ['public/build/js/*.js'],
           fn: (e, f) => {
             const bs = require('browser-sync').get('bs-webpack-plugin');
             if (e == "change" && changeECMSScript){
               bs.reload();
               changeECMSScript = false;
             }
           }
         },
         {
           match: ['templates/**/*.twig'],
           fn: (e, f) => {
             const bs = require('browser-sync').get('bs-webpack-plugin');
             if (e == "change"){
               bs.reload();
             }
           }
         }
       ]
     },
     {
       reload: false,
       name: 'bs-webpack-plugin'
     }
   )
);


webpackConfig.plugins.push(new webpack.optimize.CommonsChunkPlugin({
        names: ['vendor', 'manifest'],
        minChunks(module) {
            return module.context && /node_modules/.test(module.context);
        }
    })
);
webpackConfig.plugins.push(new UglifyJsPlugin());


webpackConfig.watchOptions = {
    poll: true,
    ignored: '/node_modules/'
};
webpackConfig.node = {
    fs: 'empty',
};

let cache_file = util.format('Resources/webpackConfig-%s.json', Encore.isProduction() ? "production" : process.env.NODE_ENV);
//console.log(util.inspect(webpackConfig));
const replacerMDN = () => {
  const seen = new WeakSet();
  return (key, value) => {
    if (typeof value === "object" && value !== null) {
      if (seen.has(value)) {
        return;
      }
      seen.add(value);
    }
    return value;
  };
};

fs.writeFile(cache_file, JSON.stringify(webpackConfig, replacerMDN, 2), function(err) {
    console.log(cache_file+" was saved for debugging purpose");
});

module.exports = webpackConfig;

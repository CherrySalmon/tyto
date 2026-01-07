
const path = require('path');
const HtmlWebpackPlugin = require('html-webpack-plugin');
const { VueLoaderPlugin } = require('vue-loader');
const AutoImport = require('unplugin-auto-import/webpack')
const Components = require('unplugin-vue-components/webpack')
const { ElementPlusResolver } = require('unplugin-vue-components/resolvers')

//Just to help us with directories and folders path
const __base = path.resolve(__dirname, '..');
const __src = path.resolve(__base, 'frontend_app');

const webpack = require('webpack');
const dotenv = require('dotenv');

// On Heroku, env vars are set directly via config vars
// Locally, load from .env.local file if env vars aren't already set
if (!process.env.VUE_APP_GOOGLE_CLIENT_ID) {
    dotenv.config({ path: path.resolve(__base, 'frontend_app', '.env.local') });
}

module.exports = {
    //Entry: main file that init our application
    entry: path.resolve(__src, 'main.js'),

    //Output: result of the bundle after webpack run
    output: {
        filename: '[name].bundle.js',
        path: path.resolve(__base, 'dist'),
        clean: true,
        publicPath: '/',
    },

    //Plugins to help and include additionals functionalities to webpack
    plugins: [
        new HtmlWebpackPlugin({
            title: 'TYTO',
            favicon: path.resolve(__src, 'static', 'favicon.png'),
            template: path.resolve(__src, 'templates', 'index.html'),
        }),
        new VueLoaderPlugin(),
        AutoImport({
            resolvers: [ElementPlusResolver()],
        }),
        Components({
            resolvers: [ElementPlusResolver()],
        }),
        new webpack.DefinePlugin({
            'process.env': JSON.stringify(process.env),
            __VUE_OPTIONS_API__: true,
            __VUE_PROD_DEVTOOLS__: false,
        })
    ],

    //Webpack dosent know how to handler all type of files and what to do with them, so this section 
    //we can capture and configure a specific type of file and determine a loader plugin to process it 
    module: {
        rules: [
            //Vue loader. Says to webpack tha files with .vue extension need to be processed by the vue-loader plugin
            {
                test: /\.vue$/,
                loader: 'vue-loader'
            },
            //CSS loaders. Make possible import css files as js modules 
            {
                test: /\.css$/,
                use: ['vue-style-loader', 'css-loader']
            },
            //Indicates that png files are assets to be processed by webpack
            {
                test: /\.png$/,
                type: 'asset/resource'
            },
        ]
    }
}

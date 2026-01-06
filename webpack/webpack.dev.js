const { merge } = require('webpack-merge');
const common = require('./webpack.common');
const path = require('path');
const __base = path.resolve(__dirname, '..');
const { CleanWebpackPlugin } = require("clean-webpack-plugin");

//Configure dev enviroment by combining common configuration and adding some more options
module.exports = merge(common, {
    mode: 'development',
    // cache: false,
    // devtool: 'inline-source-map',
    // productionSourceMap: false,
    devServer: {
        static: './dist',
        historyApiFallback: true,
        hot: true,
        host: '0.0.0.0',
        allowedHosts: 'all',
        devMiddleware: {
            writeToDisk: true,
            
      }
    },
    output: {
        path: path.resolve(__dirname, '../dist'),
        filename: '[name].bundle.js'
      },
    plugins: [
        new CleanWebpackPlugin(),]
})

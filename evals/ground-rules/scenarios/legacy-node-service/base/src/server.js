const http = require('node:http');
function Start_Server(cb) { http.createServer((req,res)=>res.end('ok')).listen(0, cb); }
module.exports = { Start_Server };

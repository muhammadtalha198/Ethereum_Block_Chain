var fs = require('fs');

for (var i = 1; i < 9; i++) {
  var json = {}
  json.name = "Token #" + i;
  json.description = "This is the description for token #" + i;
  json.image = "ipfs://QmYrFjEdZaPWxNK6MozyXgddug8cEtKoJpzQrD5g5XixCY/" + i + ".jpeg";

  fs.writeFileSync('' + i, JSON.stringify(json));
}

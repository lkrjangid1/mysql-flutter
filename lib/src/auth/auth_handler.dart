part of sqljocky;

class _AuthHandler extends _Handler {
  final String _username;
  final String _password;
  final String _db;
  final List<int> _scrambleBuffer;
  final int _clientFlags;
  final int _maxPacketSize;
  final int _characterSet;
  final bool _ssl;

  _AuthHandler(String this._username, String this._password, String this._db, List<int> this._scrambleBuffer,
      int this._clientFlags, int this._maxPacketSize, int this._characterSet,
      {bool ssl: false})
      : this._ssl = false {
    log = new Logger("AuthHandler");
  }

  List<int> _getHash() {
    List<int> hash;
    if (_password == null) {
      hash = <int>[];
    } else {
      var hashedPassword = sha1.convert(utf8.encode(_password)).bytes;
      var doubleHashedPassword = sha1.convert(hashedPassword).bytes;

      var bytes = <int>[]..addAll(_scrambleBuffer)..addAll(doubleHashedPassword);
      var hashedSaltedPassword = sha1.convert(bytes).bytes;

      hash = new List<int>(hashedSaltedPassword.length);
      for (var i = 0; i < hash.length; i++) {
        hash[i] = hashedSaltedPassword[i] ^ hashedPassword[i];
      }
    }
    return hash;
  }

  Buffer createRequest() {
    // calculate the mysql password hash
    var hash = _getHash();

    var encodedUsername = _username == null ? [] : utf8.encode(_username);
    var encodedDb;

    var size = hash.length + encodedUsername.length + 2 + 32;
    var clientFlags = _clientFlags;
    if (_db != null) {
      encodedDb = utf8.encode(_db);
      size += encodedDb.length + 1;
      clientFlags |= CLIENT_CONNECT_WITH_DB;
    }

    var buffer = new Buffer(size);
    buffer.seekWrite(0);
    buffer.writeUint32(clientFlags);
    buffer.writeUint32(_maxPacketSize);
    buffer.writeByte(_characterSet);
    buffer.fill(23, 0);
    buffer.writeNullTerminatedList(encodedUsername);
    buffer.writeByte(hash.length);
    buffer.writeList(hash);

    if (_db != null) {
      buffer.writeNullTerminatedList(encodedDb);
    }

    return buffer;
  }
}

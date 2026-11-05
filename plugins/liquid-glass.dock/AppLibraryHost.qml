import QtQuick

// Liquid Glass : un plugin tiers ne reçoit shell.appLibrary que s'il déclare le
// type « menu ». Ce menu vide n'existe que pour ça ; il ne s'ouvre jamais.
Item {
  property var shell: null
  readonly property bool opened: false
  function open(payload) {}
  function close() {}
}

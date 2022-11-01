import QtQuick 2.15
import QtQuick.Controls 1.4

Item {
    property alias combobox: tagbox
    property alias combobox_input: tagbox_input
    width: childrenRect.width
    height: childrenRect.height

    ComboBox{
        id: tagbox

        //width: 100
        editable: true
        TextField
        {
            id: tagbox_input

            width: parent.width;
            height: parent.height;
            placeholderText: qsTr("Ingrese valor");
            validator: RegExpValidator{ regExp: /\d{1,7}([.]\d{1,3})+$|\d{1,7}/ }
            anchors.top: parent.bottom
            anchors.topMargin: 5
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

}

import QtQuick 2.0
import QtQuick.Controls //1.1

Item
{
    id: container

    property alias name: title.text
    property alias paramText: paramfield.text
    property alias help: helpText.text
    property string helpSide: ""
    property alias input: paramfield
    property alias placeholder: paramfield.placeholderText
    width: 140;
    height: 25;

    TextField
    {
        id: paramfield

        width: parent.width;
        height: parent.height;
        placeholderText: qsTr("Dimensión en mm");
        //validator: RegExpValidator{ regExp: /\d{1,7}([.]\d{1,3})$|\d{1,7}/ }
    }

    Text
    {
        id: title;

        text: qsTr(name);
        anchors.right: paramfield.left;
        anchors.verticalCenter: paramfield.verticalCenter;
        anchors.rightMargin: 20;
    }

    Rectangle
    {
        id: helpZone;

        width: helpText.contentWidth+10;
        height: helpText.contentHeight+5;
        border.width: 1;
        color: "#fffaf0";
        anchors.margins: 20
        anchors.verticalCenter: (helpSide == "left" || helpSide == "right") ? paramfield.verticalCenter : undefined
        anchors.horizontalCenter: (helpSide == "below" || helpSide == "above") ? paramfield.horizontalCenter : undefined
        anchors.right: (helpSide == "left") ? paramfield.left : undefined
        anchors.left: (helpSide == "right") ? paramfield.right : undefined
        anchors.top: (helpSide == "below") ? paramfield.bottom : undefined
        anchors.bottom: (helpSide == "above") ? paramfield.top : undefined
        visible: (help == "") ? false : paramfield.hovered;
        z: 100;

        Text
        {
            id: helpText;
            anchors.centerIn: parent
        }
    }
}

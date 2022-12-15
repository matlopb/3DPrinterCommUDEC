import QtQuick 2.15
import QtQuick 2.7
import QtQuick.Window 2.15
import QtQuick 2.2
import QtQuick.Controls //1.1
import QtQuick.Controls 2.15 as QQC2
//import QtQuick.Controls.Styles 1.1
import QtQml.Models 2.15 as Modelsq
import QtQuick.Layouts 1.1
import QtQuick.Dialogs //1.1
import QtQuick.Window 2.2
import QtQml 2.0

import UM 1.2 as UM
import Cura 1.0 as Cura


Window
{
    property variant win;

    id: dialog

    title: "Plugin UDEC";
    color: "#EBEBEB"
    width: {
        if (Qt.platform.os == "linux"){
            730 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            900 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            900 * screenScaleFactor
        }
    }
    height: {
        if (Qt.platform.os == "linux"){
            590 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            750 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            750 * screenScaleFactor
        }
    }
    minimumHeight: {
        if (Qt.platform.os == "linux"){
            580 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            750 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            750 * screenScaleFactor
        }
    }
    minimumWidth: {
        if (Qt.platform.os == "linux"){
            730 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            900 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            900 * screenScaleFactor
        }
    }

    Component.onCompleted: {
            x = Screen.width / 2 - width / 2
            y = Screen.height / 2 - height / 2
        }

    Connections {
        target: manager

        function onProgressEnd() {
            win.close()
            var mDialog = Qt.createComponent("MessageDialog.qml");
            win = mDialog.createObject(dialog)
            win.show()
        }
        function onFileChanged(filecontenttext) {
            fileContent.text = filecontenttext
        }
    }

    Button
    {
        id: createInstructionsButton;
        width: 200;
        height: 30;
        anchors.right: cancelButton.left;
        anchors.rightMargin: 30;
        anchors.verticalCenter: cancelButton.verticalCenter;
        onClicked:{
            if (gcodeContent.text == "No gcode in system"){
                manager.set_message_params("e", "Operacion invalida", "No existe un codigo G disponible para generar las instrucciones. Rebane una figura e intente de nuevo.")
                manager.show_message()
            }
            else if (newFile.checked && newFileName.text == ""){
                manager.set_message_params("e", "Nombre invalido", "Ingrese un nombre para el nuevo archivo")
                manager.show_message()
            }
            else{
                var component = Qt.createComponent("ProgressBar.qml");
                win = component.createObject(dialog);
                win.show();
                manager.generatePositions(sb.paramText, sp.paramText, armLen.paramText,
                 printerH.paramText, radio.paramText, altura.paramText, fileTextfield.text, overwrite.checked,
                 newFileDir.text + "/" + newFileName.text + ".L5K", newFileDir.text)
            }
        }

        /*style: ButtonStyle
        {
            label: Image
            {
                id: writeImage;
                source: "./images/write.png";
                fillMode: Image.PreserveAspectFit;
                horizontalAlignment: Image.AlignLeft;
            }
        }*/

        Text
        {
            text: qsTr("Generar instrucciones")
            anchors.right: createInstructionsButton.right
            anchors.rightMargin: 10
            anchors.verticalCenter: createInstructionsButton.verticalCenter
        }
    }

    Button
    {
        id: cancelButton;

        width: 100;
        height: 30;
        anchors.right: mainPanel.right;
        anchors.top: mainPanel.bottom;
        anchors.topMargin: 15;
        onClicked: dialog.close();

        /*style: ButtonStyle
        {
            label: Image
            {
                id: cancelImage;
                source: "./images/cancel.png";
                fillMode: Image.PreserveAspectFit;
                horizontalAlignment: Image.AlignLeft;
            }
        }*/
        Text
        {
            text: qsTr("Cancelar")
            anchors.right: cancelButton.right
            anchors.rightMargin: 10
            anchors.verticalCenter: cancelButton.verticalCenter
        }
    }

    Rectangle
    {
        id: mainPanel;

        width: 0.95 * parent.width;
        height: 0.95 * parent.height;
        border.width: 1;
        border.color: "#AFAFAF"
        anchors.centerIn: parent;
        anchors.verticalCenterOffset: -20;

        Text
        {
            id: params;

            text: "Parametros de la impresora";
            font.bold: true;
            font.pointSize: 16;
            font.pixelSize: 20;
            anchors.top: parent.top ;
            anchors.topMargin: 20;
            anchors.left: parent.left;
            anchors.leftMargin: 40;
        }

        Text
        {
            id: fileZone;

            text: "Seleccion del archivo de destino";
            font.bold: true;
            font.pointSize: 16;
            font.pixelSize: 20;
            anchors.top: parent.top;
            anchors.topMargin: 20;
            anchors.right: parent.right;
            anchors.rightMargin: 40;
        }

        ColumnLayout
        {
            anchors.horizontalCenter: params.horizontalCenter
            anchors.top: params.bottom;
            anchors.topMargin: 20;
            anchors.left: parent.left;
            anchors.leftMargin: 140;
            spacing: 10;
            z:100
            width: dialog.width*0.2

            ParamArea{id: sb; paramText: "538"; name: "S_B"; help: " Es la distancia entre los actuadores del RDL "; helpSide: "right"}
            ParamArea{id: sp; paramText: "108"; name: "s_p"; help: " Es la distancia entre los puntos de conexion \n del efector y los brazos del robot "; helpSide: "right"}
            ParamArea{id: ub; paramText: "411"; name: "U_B"; help: " Es la distancia entre el actuador y el centro \n de la base "; helpSide: "right"}
            ParamArea{id: up; paramText: "62"; name: "u_p"; help: " Es la distancia entre el punto de conexion y \n el centro del efector "; helpSide: "right"}
            ParamArea{id: wb; paramText: "310"; name: "W_B"; help: " Es la distancia entre el centro de la base y \n el punto medio del tramo descrito por S_b "; helpSide: "right"}
            ParamArea{id: wp; paramText: "31"; name: "w_p"; help: " Es la distancia entre el efector y el punto \n medio del tramo descrito por s_p "; helpSide: "right"}
            ParamArea{id: armLen; paramText: "983"; name: "Largo de brazo"; help: " Es el largo de los brazos de la impresora "; helpSide: "right"}
            ParamArea{id: printerH; paramText: "1460"; name: "Altura impresora"; help: " Es la distancia entre la base del RDL y la \n superficie de impresion "; helpSide: "right"}
            ParamArea{id: radio; paramText: "225"; name: "Radio WS"; help: " Es el radio de la base del espacio de trabajo "; helpSide: "right"}
            ParamArea{id: altura; paramText: "500"; name: "Altura WS"; help: " Es la altura del espacio de trabajo "; helpSide: "right"}
        }

        TextField
        {
            id: fileTextfield;

            width: 150;
            height: fileButton.height;
            anchors.right: fileButton.left;
            anchors.verticalCenter: fileButton.verticalCenter;
            placeholderText: "Seleccione un archivo";
            text: fileDialog.fileUrl;

            Text
            {
                id: fileTextTitle;

                text: qsTr("Archivo de destino");
                anchors.right: parent.left;
                anchors.verticalCenter: parent.verticalCenter;
                anchors.rightMargin: 20;
            }
        }

        Button
        {
            id: fileButton;

            width: 50;
            height: 30;
            anchors.right: mainPanel.right;
            anchors.rightMargin: 20;
            anchors.top: fileZone.bottom;
            anchors.topMargin: 20;
            onClicked: fileDialog.open();

            /*style: ButtonStyle
            {
                label: Image
                {
                    id: fileImage;
                    source: "./images/browse.png";
                    fillMode: Image.PreserveAspectFit;
                }
            }*/
        }

        FileDialog
        {
            id: fileDialog;
            title: "seleccione un archivo compatible";
            nameFilters: ["Archivos RSLogix (*.L5K)","Todos los archivos(*)"];
            //folder: shortcuts.documents;
            onAccepted:
            {
                console.log("Se ha seleccionado " + fileDialog.fileUrl);

                fileContent.text = manager.showFileContent(fileDialog.fileUrl);
                fileDialog.close()
                //manager.start_worker(fileDialog.fileUrl)
            }
            onRejected:
            {
                console.log("Canceled")
                fileDialog.quit()
            }
        }

        ColumnLayout
        {
            id: selector;

            anchors.top: fileTextfield.bottom;
            anchors.topMargin: 20;
            anchors.horizontalCenter: fileTextfield.horizontalCenter;
            //ExclusiveGroup{ id: writeMethod}

            RadioButton
            {
                id: overwrite;

                checked: true;
                text: qsTr("Sobrescribir");
//                exclusiveGroup: writeMethod;
            }

            RadioButton
            {
                id: newFile;

                text: qsTr("Crear copia");
//                exclusiveGroup: writeMethod;
            }
        }

        TextField
        {
            id: newFileName;

            width: 200;
            height: fileButton.height;
            anchors.right: mainPanel.right;
            anchors.rightMargin: 20;
            anchors.top: selector.bottom ;
            anchors.topMargin: 20;
            placeholderText: "Indique un nombre";
            enabled: newFile.checked;
            validator: RegularExpressionValidator { regularExpression: /^[a-zA-Z0-9-_]+$/ }

            Text
            {
                id: newFileText;

                text: qsTr("Nombre del archivo");
                anchors.right: parent.left;
                anchors.verticalCenter: parent.verticalCenter;
                anchors.rightMargin: 20;
            }
        }

        TextField
        {
            id: newFileDir;

            width: 150;
            height: dirButton.height;
            anchors.right: dirButton.left;
            anchors.verticalCenter: dirButton.verticalCenter;
            placeholderText: "Seleccione una carpeta";
            text: dirDialog.folder;
            enabled: newFile.checked;

            Text
            {
                id: dirText;

                text: qsTr("Carpeta de destino");
                anchors.right: parent.left;
                anchors.verticalCenter: parent.verticalCenter;
                anchors.rightMargin: 20;
            }
        }

        Button
        {
            id: dirButton;

            width: 50;
            height: 30;
            anchors.right: mainPanel.right;
            anchors.rightMargin: 20;
            anchors.top: newFileName.bottom ;
            anchors.topMargin: 20;
            onClicked: dirDialog.open();
            enabled: newFile.checked;

            /*style: ButtonStyle
            {
                label: Image
                {
                    id: dirImage;
                    source: "./images/browse.png";
                    fillMode: Image.PreserveAspectFit;
                }
            }*/
        }

        FileDialog
        {
            id: dirDialog;
            title: "Seleccione una carpeta";
            //selectFolder: true;
            //folder: shortcuts.documents;
            onAccepted:
            {
                console.log("Se ha seleccionado el directorio " + dirDialog.folder);
                dirDialog.close()
            }
        }

        Rectangle
        {
            id: gcodeZone;

            width: mainPanel.width * 0.46;
            height: mainPanel.height * 0.35;
            anchors.top: altura.bottom;
            anchors.topMargin: 20;
            anchors.bottom: mainPanel.bottom;
            anchors.bottomMargin: 30;
            anchors.left: mainPanel.left;
            anchors.leftMargin: 20;
            anchors.right: mainPanel.horizontalCenter;
            anchors.rightMargin: 5;
            border.width: 1;
            Flickable
            {
                id: gcodeflickable;

                width: parent.width;
                height: parent.height;

                TextArea
                {
                    id: gcodeContent;

                    readOnly: true;
                    text: qsTr(manager.showGcode());
                    width: parent.width;
                    height: parent.height;
                    wrapMode: TextArea.WorldWrap;
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar
                {
                    parent: gcodeflickable.parent
                    anchors.top: gcodeflickable.top
                    anchors.left: gcodeflickable.right
                    anchors.bottom: gcodeflickable.bottom
                }
                QQC2.ScrollBar.horizontal: QQC2.ScrollBar
                {
                    parent: fileContentZone
                    anchors.right: gcodeflickable.right
                    anchors.left: gcodeflickable.left
                    anchors.bottom: gcodeflickable.bottom
                }

            }
        }

        Text {
            id: gcodeTitle

            text: qsTr("G-code Seleccionado");
            font.bold: true;
            font.pointSize: 16;
            font.pixelSize: 20;
            anchors.horizontalCenter: gcodeZone.horizontalCenter;
            anchors.top: gcodeZone.bottom;
        }

        Rectangle
        {
            id: fileContentZone;

            width: mainPanel.width * 0.46;
            height: mainPanel.height * 0.35;
            anchors.verticalCenter: gcodeZone.verticalCenter;
            anchors.bottom: mainPanel.bottom;
            anchors.bottomMargin: 30;
            anchors.right: mainPanel.right;
            anchors.rightMargin: 20;
            anchors.left: mainPanel.horizontalCenter;
            anchors.leftMargin: 5;
            border.width: 1;

            Flickable
            {
                id: flickable;

                width: parent.width;
                height: parent.height;

                TextArea
                {
                    id: fileContent;

                    readOnly: true;
                    width: parent.width;
                    height: parent.height;
                    wrapMode: TextArea.WorldWrap;
                }

                QQC2.ScrollBar.vertical: QQC2.ScrollBar
                {
                    parent: flickable.parent
                    anchors.top: flickable.top
                    anchors.left: flickable.right
                    anchors.bottom: flickable.bottom
                }
                QQC2.ScrollBar.horizontal: QQC2.ScrollBar
                {
                    parent: fileContentZone
                    anchors.right: flickable.right
                    anchors.left: flickable.left
                    anchors.bottom: flickable.bottom
                }

            }
        }

        Text {
            id: fileContentTitle

            text: qsTr("Archivo de destino seleccionado");
            font.bold: true;
            font.pointSize: 16;
            font.pixelSize: 20;
            anchors.horizontalCenter: fileContentZone.horizontalCenter;
            anchors.top: fileContentZone.bottom;
        }
    }
}

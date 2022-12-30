import QtQuick 2.15
import QtQml 2.0
import QtQuick.Window 2.15
import QtQuick.Controls
import QtQuick.Layouts


ApplicationWindow {
    id: login_dialog

    visible: true
    color: "#EBEBEB"
    title: qsTr("Connect to printer")
    property variant win
    property string plc_path: ""
    property var plc_info:["-----", "-----", "-----"]
    property bool tagbox1_active: false
    property bool tagbox2_active: false
    property bool tagbox3_active: false
    property bool tagbox4_active: false
    property bool connected: false
    property bool is_emergency: false
    property string total_instructions: ""
    property bool is_printing: false
    property string ws_radio: ""
    property string ws_altura: ""
    property var tb_counter: [0,0,0,0,0,0,0,0]

    width: {
        if (Qt.platform.os == "linux"){
            900 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            1100 * screenScaleFactor
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
            590 * screenScaleFactor
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
            900 * screenScaleFactor
        }
        else if (Qt.platform.os == "windows"){
            1100 * screenScaleFactor
        }
        else if (Qt.platform.os == "osx"){
            900 * screenScaleFactor
        }
    }    

    Component.onCompleted: {
            x = Screen.width / 2 - width / 2
            y = Screen.height / 2 - height / 2
            frame.height = height - 60
            frame.width = width - 50

            if (manager.look_for_gcode() == false){
                login_zone.notify_gcode_status()
            }
        }
    onWidthChanged: frame.width = width - 50
    onHeightChanged: frame.height = height - 80

    Connections {
        target: manager

        function onProgressEnd() {
            var mDialog = Qt.createComponent("MessageDialog.qml");
            win = mDialog.createObject(login_dialog)
            win.show()
        }

        function onProgressChanged(progress) {
            login_zone.change_progress(progress)
            login_zone.set_instructions_status("Cálculo en proceso...")
        }

        function onProgressTotalChanged(total) {
            console.log(total)
            login_zone.change_bar_total(total)
        }

        function onConnectionAchieved(){
            win.close()
        }
    }

    /*onClosing:{
        close.accepted = false
        monitoring_tab.item.stop_timer()
        close.accepted = true
    }*/

    Button{
        id: send_instructions

        width: 140;
        height: 50;
        enabled: connected
        anchors.right: start_printing.left
        anchors.rightMargin: 25;
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: qsTr("Enviar\ninstrucciones")
            font.weight: Font.Medium
            font.pixelSize: 14
            opacity: enabled ? 1.0 : 0.4
            horizontalAlignment: Text.AlignHCenter
        }
        Image {
            source: "./images/send.png"
            opacity: enabled ? 1 : 0.4
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: 32
        }
        onClicked:{
            manager.send_instructions()
            //manager.check_servos()
        }
    }

    Button{
        id: start_printing

        width: 120;
        height: 50;
        enabled: connected
        anchors.right: parent.right
        anchors.rightMargin: 25;
        anchors.bottom: parent.bottom
        anchors.bottomMargin: 5
        Text {
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            text: (is_printing) ? qsTr("Pausar\nimpresion") : qsTr("Iniciar\nimpresion")
            font.weight: Font.Medium
            font.pixelSize: 14
            opacity: enabled ? 1.0 : 0.4
            horizontalAlignment: Text.AlignHCenter
        }
        Image {
            source: (is_printing) ? "./images/pause.png" : "./images/play.png"
            opacity: enabled ? 1 : 0.4
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            height: 32
            width: 32
        }
        onClicked: {
            is_printing = manager.switch_printing()
            monitoring_zone.set_progress_timer(is_printing)
        }
    }    

    Button{
        id: emergency_stop

        width: 110
        height: 50
        enabled: connected
        anchors.left: parent.left
        anchors.leftMargin: 25
        anchors.verticalCenter: start_printing.verticalCenter
        contentItem: Text {
                text: qsTr("Detener \nmotores")
                font.weight: Font.Medium
                font.pixelSize: 14
                font.bold: false
                opacity: enabled ? 1.0 : 0.4
                horizontalAlignment: Text.AlignRight
                color: (emergency_stop.hovered && enabled) ? "white" : "black"
        }
        background: Rectangle {
                //opacity: enabled ? 1 : 0.7
                border.color: "darkgrey"
                color: (emergency_stop.hovered && enabled) ? Qt.lighter("red", 1.2) : 'whitesmoke'
                border.width: 1
                radius: 3
                Image {
                    source: "./images/emergency.png"
                    opacity: enabled ? 1 : 0.4
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    height: 32
                    width: 32
                }
        }
        onClicked: {
            message.text = qsTr("Está a punto de detener forzosamente los motores. \n ¿Está seguro que desea continuar?")
            is_emergency = true
            double_confirmation_window.visible = true
        }
    }

    Timer{
        id: emergency_on

        interval: 2000
        repeat: false
        running: false
        onTriggered: {manager.check_servos()}
    }

    Window{
        id: double_confirmation_window

        x: Screen.width / 2 - width / 2
        y: Screen.height / 2 - height / 2
        width: 350
        height: 150
        title: 'Detener impresión'
        visible: false

        Rectangle{
            anchors.fill: parent
            Image {
                id: message_image
                source: "./images/warning.png"
                fillMode: Image.PreserveAspectFit;
                width: 50
                height: 50
                anchors.horizontalCenter: message.horizontalCenter
                anchors.bottom: message.top
                anchors.topMargin: 20
            }

            Text {
                id: message
                anchors.bottom: buttons_row.top
                anchors.bottomMargin: 20
                anchors.horizontalCenter: buttons_row.horizontalCenter
                color: 'black'
                //text: qsTr("¿Está seguro que desea detener la impresión? \n Se perderá todo el progreso hasta ahora")
            }

            RowLayout{
                id: buttons_row
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 20
                Button{
                    id: accept

                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 30
                    contentItem: Label {
                        text: qsTr("Detener")
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {
                        if (is_emergency){manager.force_stop(); is_emergency = false; emergency_on.running = true}
                        else{manager.stop_printing()}
                        double_confirmation_window.visible = false
                        is_printing = false}
                }
                Button{
                    id: decline

                    Layout.preferredWidth: 100
                    Layout.preferredHeight: 30
                    contentItem: Label {
                        text: qsTr("Cancelar")
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                    }
                    onClicked: {double_confirmation_window.visible = false}
                }
            }
        }
    }

    header: TabBar{
        id: coreBar
        width: parent.width - 50
        anchors.horizontalCenter: parent.horizontalCenter
        TabButton{
            height: 40
            contentItem: Label {
                text: qsTr("Instrucciones y conexión")
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
        TabButton{
            height: 40
            contentItem: Label {
                text: qsTr("Monitoreo de proceso")
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
        TabButton{
            height: 40
            contentItem: Label {
                text: qsTr("Control y movimiento")
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    StackLayout {
        id: frame        
        anchors.top: coreBar.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        currentIndex: coreBar.currentIndex

        Item {
            id: login_tab

            Rectangle {
                id: login_zone
                width: login_dialog.width - 50
                height: login_dialog.height - 80
                border.width: 1

                function notify_gcode_status(){
                    set_instructions_status("No existe Gcode en el sistema.\nRebane una figura primero.")
                    generate_instructions.enabled = false
                }
                function set_instructions_status(status){
                    instructions_status_text.text = qsTr(status)
                    if (progressBar.value == progressBar.to){
                        total_instructions = manager.get_n_coor()
                        instructions_status_text.text = qsTr("Se generaron "+ total_instructions +" posiciones. Las instrucciones estan listas para su envío.")
                    }
                }
                function change_progress(progress) {
                    progressBar.value = progress
                    console.log(progress)
                }

                function change_bar_total(total) {
                    progressBar.to = total
                }

                Image {
                    id: udecLogo
                    source: "./images/udeclogo.jpg"
                    anchors.left: parent.left
                    anchors.leftMargin: 10
                    anchors.top: parent.top
                    anchors.topMargin: 10
                    width: 66
                    height: 86

                }

                Text {
                    id: udecText
                    text: qsTr("Universidad de Concepción \nDepartamento de ingenieria")
                    anchors.left: udecLogo.right
                    anchors.leftMargin: 10
                    anchors.top:  udecLogo.top
                }

                ListModel{
                    id: plc_info_model

                    ListElement{
                        name: "Nombre del \ndispositivo"
                        value: "-----------"
                    }
                    ListElement{
                        name: "Nombre del \ncontrolador"
                        value: "-----------"
                    }
                    ListElement{
                        name: "Programas"
                        value: "-----------"
                    }
                }

                Component{
                    id: my_delegate

                    Rectangle{
                        border.width: 1
                        width: 100
                        height: 40
                        color: "lightgrey"
                        Text {
                            id: model_name
                            text: name + ": "
                        }
                        Rectangle{
                            border.width: 1
                            width: 250
                            height: 40
                            color: "lightgrey"
                            anchors.left: parent.right
                            Text {
                                id: model_value
                                text: value
                            }
                        }
                    }
                }

                Text{
                    id: login_title

                    text: "Conectese a la impresora";
                    font.bold: true;
                    font.pointSize: 16;
                    font.pixelSize: 20;
                    anchors.top: udecLogo.bottom;
                    anchors.topMargin: 20;
                    anchors.left: parent.left;
                    anchors.leftMargin: 200;
                }

                ColumnLayout{
                    id: main_column

                    spacing: 30
                    anchors.horizontalCenter: login_title.horizontalCenter
                    anchors.top: login_title.bottom
                    anchors.topMargin: 30

                    Rectangle{
                        width: 400
                        height: 100

                        Text{
                            id: main_text

                            anchors.fill: parent
                            text: qsTr("       Para comenzar rebane una figura, ingrese los parametros de la impresora destino y genere intrucciones.\n      Luego ingrese la direccion IP del controlador de la impresora y presione conectar. Despues presione enviar instrucciones e iniciar impresión.")
                            wrapMode: Text.WordWrap
                            horizontalAlignment: Text.AlignJustify
                        }
                    }

                    Row{
                        id: content_Item

                        height: 30
                        Layout.preferredWidth: 200
                        Layout.alignment: Qt.AlignHCenter

                        Text{
                            id: field_Indicator

                            text: qsTr("Dirección IP: ")
                        }

                        TextField{
                            id: ip_field

                            width: 140
                            placeholderText: qsTr("e.g. 192.168.1.34/2");
                            text: qsTr("192.168.1.34/2");//qsTr("152.74.22.162/3");
                            validator: RegularExpressionValidator{ regularExpression: /^(([01]?[0-9]?[0-9]|2([0-4][0-9]|5[0-5]))\.){3}([01]?[0-9]?[0-9]|2([0-4][0-9]|5[0-5]))\/(([0-6]|3([0])|2([0-9]))\.)$/}
                        }
                    }

                    Button{
                        id: login_button

                        Layout.preferredWidth: 110
                        Layout.preferredHeight: 30
                        enabled: false
                        Layout.alignment: Qt.AlignHCenter
                        Text {
                            text: qsTr('Conectar')
                            color: generate_instructions.enabled ? "black":"darkgrey"
                            anchors.right: parent.right
                            anchors.rightMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            font.pointSize: 12
                        }
                        Image {
                            source: "./images/connect.png"
                            opacity: enabled ? 1 : 0.4
                            anchors.left: parent.left
                            anchors.leftMargin: 10
                            anchors.verticalCenter: parent.verticalCenter
                            height: 16
                            width: 16
                        }
                        onClicked: {
                            plc_path = ip_field.text
                            plc_info = manager.plc_info(plc_path)
                            connected = plc_info[3]
                            plc_info_model.setProperty(0, "value", plc_info[0])
                            plc_info_model.setProperty(1, "value", plc_info[1])
                            plc_info_model.setProperty(2, "value", plc_info[2])
                            if (connected){
                                monitoring_tab.enabled = true
                                control_tab.enabled = true
                                monitoring_zone.load_tags()
                                control_zone.get_actual_position()
                                //control_zone.get_gains()
                            }
                        }
                    }

                    ListView{
                        model: plc_info_model
                        delegate: my_delegate
                        height: 200
                    }
                }

                Text{
                    id: params_title

                    text: "Parametros de la impresora";
                    font.bold: true;
                    font.pointSize: 16;
                    font.pixelSize: 20;
                    anchors.top: parent.top;
                    anchors.topMargin: 20;
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.horizontalCenterOffset: parent.width/4
                    //anchors.rightMargin: 100;
                }

                ColumnLayout
                {
                    id: paramcolumn
                    anchors.horizontalCenter: params_title.horizontalCenter
                    anchors.top: params_title.bottom;
                    anchors.topMargin: 20;
                    Layout.preferredWidth: frame.width/2
                    Layout.preferredHeight: frame.height
                    spacing: 25;
                    z:100

                    Text{
                        id: params_subtitle

                        Layout.preferredWidth: params_title.width
                        Layout.alignment: Qt.AlignHCenter
                        text: qsTr("Para generar las instrucciones indique los \nparametros de la impresora")
                    }

                    ParamArea{id: sb; paramText: "646"; name: "S_B"; help: " Es la distancia entre los actuadores del RDL "; helpSide: "left"; Layout.alignment: Qt.AlignHCenter}
                    ParamArea{id: sp; paramText: "108"; name: "s_p"; help: " Es la distancia entre los puntos de conexion \n del efector y los brazos del robot "; helpSide: "left"; Layout.alignment: Qt.AlignHCenter}
                    ParamArea{id: armLen; paramText: "983"; name: "Largo de brazo"; help: " Es el largo de los brazos de la impresora "; helpSide: "left"; Layout.alignment: Qt.AlignHCenter}
                    ParamArea{id: printerH; paramText: "1460"; name: "Altura impresora"; help: " Es la distancia entre la base del RDL y la \n superficie de impresion "; helpSide: "left"; Layout.alignment: Qt.AlignHCenter}
                    ParamArea{id: radio; paramText: "225"; name: "Radio WS"; help: " Es el radio de la base del espacio de trabajo "; helpSide: "left"; Layout.alignment: Qt.AlignHCenter; input.onTextChanged: ws_radio = paramText}
                    ParamArea{id: altura; paramText: "505"; name: "Altura WS"; help: " Es la altura del espacio de trabajo "; helpSide: "left"; Layout.alignment: Qt.AlignHCenter; input.onTextChanged: ws_altura = paramText}

                    Rectangle{
                        id: instructions_status

                        Layout.preferredWidth: login_zone.width/3
                        Layout.preferredHeight: 150
                        color: "whitesmoke"
                        Layout.alignment: Qt.AlignHCenter
                        border.width: 1

                        Text{
                            id: instructions_status_text

                            height: 30
                            width: parent.width - 50
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: parent.top
                            anchors.topMargin: 10
                            text: qsTr("No existen instrucciones en memoria.")
                            horizontalAlignment: Text.AlignHCenter
                            wrapMode: Text.WordWrap
                        }
                        ProgressBar {
                            id: progressBar
                            width: parent.width - 100
                            height: 20
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.top: instructions_status_text.bottom
                            anchors.topMargin: 20
                            from: 0
                            background: Rectangle {
                                            anchors.fill: parent
                                            color: "white"
                                            border.width: 1
                                            border.color: 'black'
                            }
                            contentItem: Rectangle {
                                            anchors.left: parent.left
                                            anchors.verticalCenter: parent.verticalCenter
                                            height: parent.height - 4
                                            width: parent.width * (parent.value/parent.to)
                                            color: 'dodgerblue'
                            }
                        }
                        Button{
                            id: generate_instructions

                            width: 250
                            height: 50
                            anchors.horizontalCenter: parent.horizontalCenter
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 10
                            enabled: true
                            Text {
                                text: qsTr("Generar instrucciones")
                                color: generate_instructions.enabled ? "black":"darkgrey"
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                font.pointSize: 14
                            }
                            Image {
                                source: "./images/write.png"
                                opacity: enabled ? 1 : 0.4
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 32
                                width: 32
                            }
                            onClicked: {
                                manager.generate_instructions_list(sb.paramText, sp.paramText, armLen.paramText,
                                                                   printerH.paramText, radio.paramText, altura.paramText)
                                login_button.enabled = true
                            }
                        }
                    }
                }
            }
        }
//#################################################################################################################################################################################################
//#################################################################################################################################################################################################
        Item {
            id: monitoring_tab

            Rectangle {
                id: monitoring_zone

                width: login_dialog.width - 50
                height: login_dialog.height - 80
                border.width: 1

                function load_tags(){
                    var tag_list = ["Seleccione un tag..."]
                    var get_list = manager.plc_tag_list(plc_path)
                    for(let element in get_list){
                        tag_list.push(get_list[element])
                    }
                    tagbox_1.combobox.model = tag_list
                    tagbox_2.combobox.model = tag_list
                    tagbox_3.combobox.model = tag_list
                    tagbox_4.combobox.model = tag_list
                    tagbox2_1.combobox.model = tag_list
                    tagbox2_2.combobox.model = tag_list
                    tagbox2_3.combobox.model = tag_list
                    tagbox2_4.combobox.model = tag_list
                }
                function set_progress_timer(state) {progress_timer.running = state}
                function stop_timer() {date_timer.running = false}

                Text{
                    id: tab_title

                    text: "Monitoreo de variables"
                    z: 100
                    font.bold: true;
                    font.pointSize: 16;
                    font.pixelSize: 20;
                    anchors.top: parent.top;
                    anchors.topMargin: 20;
                    anchors.horizontalCenter: progress_status.horizontalCenter

                }

                Rectangle{
                    id: chart_rect1

                    border.width: 1
                    width: parent.width/2
                    height: parent.height/2 - 15
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: 10
                    color: "whitesmoke"

                    RowLayout{
                        id: combobox_row

                        spacing: 5
                        anchors.horizontalCenter: chart.horizontalCenter
                        anchors.top: chart.bottom
                        anchors.topMargin: 10

                        Tagbox{
                            id: tagbox_1

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox1_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                        Tagbox{
                            id: tagbox_2

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox2_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                        Tagbox{
                            id: tagbox_3

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox3_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                        Tagbox{
                            id: tagbox_4

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox4_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                    }

                    Image {
                        id: chart
                        width: parent.width -50
                        height: parent.height - 80
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        source: "image://perflog/plot_one"
                    }

                    Timer{
                        id: image_timer
                        interval: 1000
                        running: false
                        repeat: true
                        onTriggered:{
                            manager.plot('plot_one')
                            reload1()
                            manager.plot('plot_two')
                            reload2()
                        }
                        function reload1() { var t = chart.source; chart.source = ""; chart.source = t; }
                        function reload2() { var t = chart2.source; chart2.source = ""; chart2.source = t; }
                    }
                }
                //----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
                Rectangle{
                    id: chart_rect2

                    border.width: 1
                    width: parent.width/2
                    height: parent.height/2 - 15
                    anchors.left: parent.left
                    anchors.bottom: parent.bottom
                    anchors.margins: 10
                    color: "whitesmoke"

                    RowLayout{
                        id: combobox_row2

                        spacing: 5
                        anchors.horizontalCenter: chart2.horizontalCenter
                        anchors.top: chart2.bottom

                        Tagbox{
                            id: tagbox2_1

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox1_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                        Tagbox{
                            id: tagbox2_2

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox2_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                        Tagbox{
                            id: tagbox2_3

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox3_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                        Tagbox{
                            id: tagbox2_4

                            combobox.onActivated: {
                                date_timer.running = true
                                tagbox4_active = true
                            }
                            combobox_input.onAccepted: {
                                manager.write_value(combobox.currentText, combobox_input.text)
                            }
                        }
                    }

                    Image {
                        id: chart2
                        width: parent.width -50
                        height: parent.height - 80
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        //source: "./images/2wayarrow.png"
                        source: "image://perflog/plot_two"
                    }
                }

                Rectangle{
                    id: progress_status

                    width: frame.width/2 - 50
                    height: 150
                    color: "whitesmoke"
                    border.width: 1
                    anchors.bottom: parent.bottom
                    anchors.right: parent.right
                    anchors.margins: 20

                    Text{
                        id: progress_text

                        height: 30
                        width: contentWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        font.pointSize: 14
                        text: qsTr("Avance del proceso:")
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text{
                        id: progress_step

                        height: 30
                        width: contentWidth
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: progress_text.bottom
                        anchors.topMargin: 20
                        text: qsTr("Instrucciones completadas: 0/?")
                        font.bold: true
                        font.pointSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                    Text{
                        id: percentage_text
                        z:100

                        height: 30
                        width: contentWidth
                        anchors.horizontalCenter: process_progressBar.horizontalCenter
                        anchors.verticalCenter: process_progressBar.verticalCenter
                        anchors.verticalCenterOffset: 2
                        text: qsTr("00 %")
                        font.bold: true
                        font.pointSize: 14
                        horizontalAlignment: Text.AlignHCenter
                    }
                    ProgressBar {
                        id: process_progressBar
                        height: 20
                        width: 350//parent.width - 100
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 20
                        from: 0
                        to: 100
                        background: Rectangle {
                                        anchors.fill: parent
                                        color: "white"
                                        border.width: 1
                                        border.color: 'black'
                        }
                        contentItem: Item {
                            implicitWidth: 200
                            implicitHeight: 4
                            Rectangle {
                                        id: content
                                        height: parent.height - 4
                                        width: process_progressBar.width * (process_progressBar.value/process_progressBar.to)
                                        color: 'dodgerblue'
                            }
                        }
                    }
                    Timer{
                        id: progress_timer
                        interval: 2000
                        repeat: true
                        running: false
                        onTriggered: {
                            var progress = manager.get_progress_percentage()
                            percentage_text.text = progress[0].toString() + "%"
                            process_progressBar.value = progress[0]
                            progress_step.text = "Instrucciones completadas: " + progress[1]+"/"+total_instructions
                            progress_text.text = "Avance del proceso:"
                            if (progress[0] >= 100){
                                progress_text.text = "Proceso terminado."
                                progress_timer.running = false
                                is_printing = false
                            }
                        }
                    }
                }

                Timer{
                    id: date_timer
                    interval: 1000
                    running: false
                    repeat: true
                    onTriggered: {

                        /*
                        PSEUDO CODE

                        p-function creates an array of 60 non-visible elements (60 seconds)

                        every 1 seconds:
                            get the tags in the tagboxes
                            if no tags are selected:
                                stop
                            feed them to the python functions which make the plot
                            *in python*:
                                read value of tags
                                append the read value to the end of array
                                remove first element of array
                                plot the values

                        */

                        var upper_tagboxes_info = {"tagbox_1" : [tagbox1_active, tagbox_1.combobox.currentText, 0, tb_counter[0]], "tagbox_2" : [tagbox2_active, tagbox_2.combobox.currentText, 1, tb_counter[1]], "tagbox_3" : [tagbox3_active, tagbox_3.combobox.currentText, 2, tb_counter[2]], "tagbox_4" : [tagbox4_active, tagbox_4.combobox.currentText, 3, tb_counter[3]]}
                        var lower_tagboxes_info = {"tagbox2_1" : [tagbox1_active, tagbox2_1.combobox.currentText, 4, tb_counter[4]], "tagbox2_2" : [tagbox2_active, tagbox2_2.combobox.currentText, 5, tb_counter[5]], "tagbox2_3" : [tagbox3_active, tagbox2_3.combobox.currentText, 6, tb_counter[6]], "tagbox2_4" : [tagbox4_active, tagbox2_4.combobox.currentText, 7, tb_counter[7]]}
                        var upper_active_tagboxes = who_active(upper_tagboxes_info)
                        var lower_active_tagboxes = who_active(lower_tagboxes_info)
                        update_charts(upper_active_tagboxes, lower_active_tagboxes)

                        reload1()
                        reload2()
                    }

                    function reload1() { var t = chart.source; chart.source = ""; chart.source = t; }
                    function reload2() { var t = chart2.source; chart2.source = ""; chart2.source = t; }

                    function who_active(tagbox_dict){
                        var active_elements = {}
                        for (let tag in tagbox_dict){
                            if (tagbox_dict[tag][0] && tagbox_dict[tag][1] != "Seleccione un tag..."){
                                tb_counter[tagbox_dict[tag][2]]++
                                active_elements[tag] = [tagbox_dict[tag][1], tagbox_dict[tag][2], tagbox_dict[tag][3]]
                            }
                            else{
                                tagbox_dict[tag][3] = 0
                            }
                        }
                        return active_elements
                    }

                    function update_charts(upper_tag_dict, lower_tag_dict){
                        var tag_names = []
                        var tag_counter = []
                        var tag_spot = []
                        var upper_len = 0
                        var lower_len = 0
                        for (let upper_tag in upper_tag_dict){
                            tag_names.push(upper_tag_dict[upper_tag][0])
                            tag_counter.push(upper_tag_dict[upper_tag][2])
                            tag_spot.push(upper_tag_dict[upper_tag][1])
                            upper_len++
                        }
                        for (let lower_tag in lower_tag_dict){
                            tag_names.push(lower_tag_dict[lower_tag][0])
                            tag_counter.push(lower_tag_dict[lower_tag][2])
                            tag_spot.push(lower_tag_dict[lower_tag][1])
                            lower_len++
                        }

                        if (tag_names.length != 0){
                            console.log(tag_counter)
                            var tagbox_values = manager.update_series(tag_names, tag_counter, tag_spot, upper_len, lower_len)
                            var counter = 0
                            for (let u_element in upper_tag_dict){
                                fill_text(tagbox_values[counter], upper_tag_dict[u_element][1], "up")
                                counter++
                            }
                            for (let l_element in lower_tag_dict){
                                fill_text(tagbox_values[counter], lower_tag_dict[l_element][1], "down")
                                counter++
                            }
                        }
                    }

                    function fill_text(value, tagbox_n, side){
                        var upper_input_boxes = {"0":tagbox_1.combobox_input, "1":tagbox_2.combobox_input, "2":tagbox_3.combobox_input, "3":tagbox_4.combobox_input}
                        var lower_input_boxes = {"0":tagbox2_1.combobox_input, "1":tagbox2_2.combobox_input, "2":tagbox2_3.combobox_input, "3":tagbox2_4.combobox_input}
                        if (side=="up"){
                            upper_input_boxes[tagbox_n.toString()].placeholderText = value
                        }
                        else if(side=="down"){
                            lower_input_boxes[tagbox_n.toString()].placeholderText = value
                        }
                    }

                }
            }
        }
//#################################################################################################################################################################################################
//#################################################################################################################################################################################################

        Item {
            id: control_tab

            Rectangle {
                id: control_zone

                width: login_dialog.width - 50
                height: login_dialog.height - 80
                border.width: 1

                function get_actual_position(){
                    //var actual_position = manager.get_actual_position()
                    eje_x.paramText = 0//actual_position[0]
                    eje_y.paramText = 0//actual_position[1]
                    eje_z.paramText = 0//actual_position[2]
                }

                function get_gains(){
                    var gains = manager.get_gains()
                    kff_a.placeholder = gains[0].toString()
                    kff_v.placeholder = gains[1].toString()
                    kp_v.placeholder = gains[2].toString()
                    ki_v.placeholder = gains[3].toString()
                    kp_p.placeholder = gains[4].toString()
                    ki_p.placeholder = gains[5].toString()
                }

                Text{
                    id: control_title

                    text: "Control de movimiento del efector";
                    font.bold: true;
                    font.pointSize: 16;
                    font.pixelSize: 20;
                    anchors.top: parent.top;
                    anchors.topMargin: 20;
                    anchors.left: parent.left;
                    anchors.leftMargin: 150;
                }

                Rectangle{
                    id: crossreference
                    width: 80
                    height: 80
                    anchors.verticalCenter: zreference.verticalCenter
                    anchors.left: zreference.right
                    anchors.leftMargin: 150
                }

                ArrowButtons{id: right; anchors.left: crossreference.right; anchors.top: crossreference.top; rotation: 0; transform: Rotation{origin.x: 0; origin.y: 0; angle: 0}
                             highButton.onClicked: {eje_x.paramText =  parseInt(eje_x.paramText) + 100}
                             lowButton.onClicked: {eje_x.paramText = parseInt(eje_x.paramText) + 10}}
                ArrowButtons{id: upup; anchors.left: crossreference.left; anchors.top: crossreference.top; rotation: 270; transform: Rotation{origin.x: 0; origin.y: 0; angle: 270}
                             highButton.onClicked: {eje_y.paramText =  parseInt(eje_y.paramText) + 100}
                             lowButton.onClicked: {eje_y.paramText = parseInt(eje_y.paramText) + 10}}
                ArrowButtons{id: down; anchors.top: crossreference.bottom; anchors.left: crossreference.right; rotation: 90; transform: Rotation{origin.x: 0; origin.y: 0; angle: 90}
                             highButton.onClicked: {eje_y.paramText = parseInt(eje_y.paramText) - 100}
                             lowButton.onClicked: {eje_y.paramText = parseInt(eje_y.paramText) - 10}}
                ArrowButtons{id: left;  anchors.top: crossreference.bottom ; anchors.left: crossreference.left; rotation: 180; transform: Rotation{origin.x: 0; origin.y: 0; angle: 180}
                             highButton.onClicked: {eje_x.paramText =  parseInt(eje_x.paramText) - 100}
                             lowButton.onClicked: {eje_x.paramText = parseInt(eje_x.paramText) - 10}}

                Rectangle{
                    id: zreference
                    width: 80
                    height: 80
                    anchors.left: parent.left
                    anchors.leftMargin: 100
                    anchors.verticalCenter: parent.verticalCenter
                }

                ArrowButtons{id: zup; anchors.left: zreference.left; anchors.top: zreference.top; rotation: 270; transform: Rotation{origin.x: 0; origin.y: 0; angle: 270}
                             highButton.onClicked: {eje_z.paramText =  parseInt(eje_z.paramText) + 100}
                             lowButton.onClicked: {eje_z.paramText = parseInt(eje_z.paramText) + 10}}
                ArrowButtons{id: zdown; anchors.top: zreference.bottom; anchors.left: zreference.right; rotation: 90; transform: Rotation{origin.x: 0; origin.y: 0; angle: 90}
                             highButton.onClicked: {eje_z.paramText =  parseInt(eje_z.paramText) - 100}
                             lowButton.onClicked: {eje_z.paramText = parseInt(eje_z.paramText) - 10}}
                Image {
                    id: doublearrow
                    width: 300
                    height: 350
                    anchors.right: zreference.left
                    anchors.rightMargin: -100
                    anchors.verticalCenter: zreference.verticalCenter
                    source: "./images/2wayarrow.png"
                    Text {
                        id: toptext
                        text: qsTr("500")
                        font.bold: true
                        font.pointSize: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.top
                        anchors.bottomMargin: -30
                    }
                    Text {
                        id: bottomtext
                        text: qsTr("0")
                        font.bold: true
                        font.pointSize: 16
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: -30
                    }
                    Text {
                        text: qsTr("Z")
                        font.bold: true
                        font.pointSize: 16
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left: bottomtext.left
                        anchors.leftMargin: -15
                    }
                }
                Image {
                    id: y_arrow
                    source: "./images/2wayarrow.png"
                    anchors.centerIn: crossreference
                    width: 90
                    height: 90
                    Text {
                        id: y_label
                        text: qsTr("Y")
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: 10
                        anchors.top: parent.top
                    }
                }
                Image {
                    id: x_arrow
                    source: "./images/2wayarrow.png"
                    anchors.centerIn: crossreference
                    transform: Rotation{origin.x: x_arrow.width/2; origin.y: x_arrow.height/2; angle: 90}
                    width:90
                    height: 90
                    Text {
                        id: x_label
                        text: qsTr("X")
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.horizontalCenterOffset: 10
                        anchors.top: parent.top
                        transform: Rotation{origin.x: x_label.width/2; origin.y: x_label.height/2; angle: -90}
                    }
                }

                RowLayout{
                    spacing: 30
                    anchors.horizontalCenter: max_speed.horizontalCenter
                    anchors.bottom: max_speed.top
                    anchors.bottomMargin: 10
                    ParamArea{id: eje_x; name: "Eje X"; help: " Indique un valor entre -" + ws_radio + " y " + ws_radio; helpSide: "above"; input.width: 100; input.onTextChanged:  {if (parseInt(eje_x.paramText) > parseInt(ws_radio)){eje_x.paramText = parseInt(ws_radio)} if (parseInt(eje_x.paramText) < -parseInt(ws_radio)){eje_x.paramText = -parseInt(ws_radio)}}}
                    ParamArea{id: eje_y; name: "Eje Y"; help: " Indique un valor entre -" + ws_radio + " y " + ws_radio; helpSide: "above"; input.width: 100; input.onTextChanged:  {if (parseInt(eje_y.paramText) > parseInt(ws_radio)){eje_y.paramText = parseInt(ws_radio)} if (parseInt(eje_y.paramText) < -parseInt(ws_radio)){eje_y.paramText = -parseInt(ws_radio)}}}
                    ParamArea{id: eje_z; name: "Eje Z"; help: " Indique un valor entre 0 y " + ws_altura; helpSide: "above"; input.width: 100; input.onTextChanged:  {if (parseInt(eje_z.paramText) > parseInt(ws_altura)){eje_z.paramText = parseInt(ws_altura)} if (parseInt(eje_z.paramText) < 0){eje_z.paramText = 0}}}
                }

                ParamArea{id: max_speed; name: "Veloc. de efector"; placeholder: qsTr("Dimension en m/s"); anchors.horizontalCenter: make_move.horizontalCenter; anchors.bottom: make_move.top; anchors.bottomMargin: 10; input.onAccepted: {manager.write_value("jerk_speed", max_speed.paramText)}}

                Button{
                    id: make_move

                    width: 250
                    height: 50
                    anchors.horizontalCenter: control_title.horizontalCenter
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: 10
                    Text {
                        text: qsTr("Realizar movimiento")
                        color: make_move.enabled ? "black":"darkgrey"
                        anchors.right: parent.right
                        anchors.rightMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        font.pointSize: 14
                        font.bold: true
                    }
                    Image {
                        source: "./images/move.png"
                        opacity: enabled ? 1 : 0.4
                        anchors.left: parent.left
                        anchors.leftMargin: 10
                        anchors.verticalCenter: parent.verticalCenter
                        height: 32
                        width: 32
                    }
                    onClicked: {
                        manager.move_to(eje_x.paramText, eje_y.paramText, -eje_z.paramText)
                    }
                }

                Rectangle{
                    id: utilities
                    width: childrenRect.width + 50
                    height: childrenRect.height + 20
                    anchors.right: parent.right
                    anchors.rightMargin: 30
                    anchors.verticalCenter: parent.verticalCenter
                    border.width: 1
                    color: "whitesmoke"

                    Text {
                        id: utilities_title
                        text: "Funciones utiles";
                        font.bold: true;
                        font.pointSize: 16;
                        font.pixelSize: 20;
                        anchors.top: parent.top;
                        anchors.topMargin: 10
                        anchors.horizontalCenter: parent.horizontalCenter
                    }

                    ColumnLayout{
                        spacing: 15
                        anchors.top: utilities_title.bottom
                        anchors.topMargin: 30
                        anchors.horizontalCenter: parent.horizontalCenter

                        Button{
                            id: move_home

                            Layout.preferredWidth: 250
                            Layout.preferredHeight: 50
                            Layout.alignment: Qt.AlignHCenter
                            Text {
                                text: qsTr("Volver al origen")
                                color: move_home.enabled ? "black":"darkgrey"
                                anchors.right: parent.right
                                anchors.rightMargin: 30
                                anchors.verticalCenter: parent.verticalCenter
                                font.pointSize: 14
                                font.bold: true
                            }
                            Image {
                                source: "./images/home.png"
                                opacity: enabled ? 1 : 0.4
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 32
                                width: 32
                            }
                            onClicked: {
                                manager.run_home()
                            }
                        }
                        Button{
                            id: stop_printing

                            Layout.preferredWidth: 250
                            Layout.preferredHeight: 50
                            Layout.alignment: Qt.AlignHCenter
                            Text {
                                text: qsTr("Detener impresion")
                                color: stop_printing.enabled ? "black":"darkgrey"
                                anchors.right: parent.right
                                anchors.rightMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                font.pointSize: 14
                                font.bold: true
                            }
                            Image {
                                source: "./images/warning.png"
                                opacity: enabled ? 1 : 0.4
                                anchors.left: parent.left
                                anchors.leftMargin: 10
                                anchors.verticalCenter: parent.verticalCenter
                                height: 32
                                width: 32
                            }
                            onClicked: {
                                message.text = qsTr("¿Está seguro que desea detener la impresión? \n Se perderá todo el progreso hasta ahora")
                                double_confirmation_window.visible = true
                            }
                        }

                        SpinBox{
                            id: speed_tune_button

                            Layout.preferredWidth: 100
                            Layout.preferredHeight: 25
                            Layout.alignment: Qt.AlignRight
                            to: 200
                            from: 1
                            value: 100
                            textFromValue: function(value){return value.toString()+'%'}
                            onValueModified: {console.log("valor cambiado a " + value)}//; manager.tune_speed(value)}
                        }

                        ParamArea{id: kff_a; name: "Kff aceleración"; placeholder: qsTr("ingrese un valor"); help: "Ganancia de pre-alimentación de acceleración"; helpSide: "left";
                                  Layout.alignment: Qt.AlignRight; input.onAccepted: {manager.tune_gain("SV_accelFFgain", "sw_accelFFGain", kff_a.paramText)}}
                        ParamArea{id: kff_v; name: "Kff velocidad"; placeholder: qsTr("ingrese un valor"); help: "Ganancia de pre-alimentación de velocidad"; helpSide: "left";
                                  Layout.alignment: Qt.AlignRight; input.onAccepted: {manager.tune_gain("SV_velocFFgain", "sw_velocFFGain", kff_v.paramText)}}
                        ParamArea{id: kp_p; name: "Kp posición"; placeholder: qsTr("ingrese un valor"); help: "Ganancia proporcional de posición"; helpSide: "left"; Layout.alignment: Qt.AlignRight;
                                  input.onAccepted: {manager.tune_gain("SV_posPropgain", "sw_posPropGain", kp_p.paramText)}}
                        ParamArea{id: ki_p; name: "Ki posición"; placeholder: qsTr("ingrese un valor"); help: "Ganancia integral de posición"; helpSide: "left"; Layout.alignment: Qt.AlignRight;
                                  input.onAccepted: {manager.tune_gain("SV_posItggain", "sw_posItgGain", ki_p.paramText)}}
                        ParamArea{id: kp_v; name: "Kp velocidad"; placeholder: qsTr("ingrese un valor"); help: "Ganancia proporcional de velocidad"; helpSide: "left"; Layout.alignment: Qt.AlignRight;
                                  input.onAccepted: {manager.tune_gain("SV_velocPropgain", "sw_velocPropGain", kp_v.paramText)}}
                        ParamArea{id: ki_v; name: "Ki velocidad"; placeholder: qsTr("ingrese un valor"); help: "Ganancia integral de velocidad"; helpSide: "left"; Layout.alignment: Qt.AlignRight;
                                  input.onAccepted: {manager.tune_gain("SV_velocItggain", "sw_velocItgGain", ki_v.paramText)}}
                    }
                }
            }
        }
    }
}

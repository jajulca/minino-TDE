#!/bin/bash

# =============================================================================
# Script para ejecutar en la iso y dar opción a añadir mejoras.
# =============================================================================

# -----------------------------------------------------------------------------
# Configuración del script
# -----------------------------------------------------------------------------

# Constante que impide que se ejecuten las opciones elegidas

readonly DEBUG='y'

# -----------------------------------------------------------------------------
# Definición de las funciones utilizadas en el script
# -----------------------------------------------------------------------------

#==============================================================================
# Gestión del autologin en el sistema
#==============================================================================

# Activa el autologin para el usuario "usuario"
# ---

function activarAutoLogin {

sudo cat << EOF >> /etc/lightdm/lightdm.conf 

[Seat:*]
pam-service=lightdm
pam-autologin-service=lightdm-autologin
autologin-user=usuario
autologin-user-timeout=0
session-wrapper=/etc/X11/Xsession
greeter-session=lightdm-greeter

EOF

}

# Desactiva el acceso automático al sistema
# ---

function activarAutoLoginUndo {
    sudo sed -e '/\[Seat\:\*\]/,+7d' < /etc/lightdm/lightdm.conf > /tmp/lightdm.conf
    sudo mv /tmp/lightdm.conf /etc/lightdm/lightdm.conf
}

# Comprueba si está activo el acceso automático al sistema
# ---

function activarAutoLoginCheck {
    grep -q pam-autologin-service=lightdm-autologin /etc/lightdm/lightdm.conf > /dev/null 2>&1
	[ $? = 0 ] && echo "True" || echo "False"
}

# Ejecuta la función correspondiente a cada una de las opciones del script
# ---

function ejecutarAccionOpcional {
    ($1)
}

#==============================================================================
# Gestión del acceso por SSH
#==============================================================================

# Instala SSHD para permitir la conexión remota por SSH a Minino-TDE
# ---

function accesoSSH {
     sudo apt install openssh-server -y
}

# Desactiva el acceso por SSH
# ---

function accesoSSHUndo {
     sudo apt remove openssh-server -y
}

# Comprueba si está activo el acceso por SSH
# ---

function accesoSSHCheck {
    dpkg-query -l openssh-server > /dev/null 2>&1
	[ $? = 0 ] && echo "True" || echo "False"
}

#==============================================================================
# Gestión del modo privado en los navegadores del sistema
#==============================================================================

# Activa el modo incógnito tanto en Firefox como en Chromium
# ---

function navegacionPrivada {

    # Modo incógnito en los Firefox del sistema
    # ---

    # En el Firefox-latest de usuario/usuario
	 sudo sed -i -e 's/firefox\-latest\/firefox --private-window/firefox\-latest\/firefox/g' /home/$USER/Escritorio/firefox-latest.desktop

	# En el Firefox-latest del sistema
	 sudo sed -i -e 's/firefox\-latest\/firefox --private-window/firefox\-latest\/firefox/g' /usr/share/applications/firefox-latest.desktop

    # En el firefox-esr del sistema (para todos los usuarios)
     sudo sed -i -e 's/firefox-esr --private-window %u/firefox-esr %u/g' /usr/share/applications/firefox-esr.desktop

    # Modo incógnito en Chromium
    # ---

     sudo sed -i -e 's/chromium --incognito %U/chromium %U/g' /usr/share/applications/chromium.desktop

}

# Desactiva el modo incógnito en los navegadores del sistema
# ---

function navegacionPrivadaUndo {
    
    # Modo incógnito en los Firefox del sistema
    # ---

    # En el Firefox-latest de usuario/usuario
	sudo sed -i -e 's/firefox\-latest\/firefox/firefox\-latest\/firefox --private-window/g' /home/$USER/Escritorio/firefox-latest.desktop

	# En el Firefox-latest del sistema
	sudo sed -i -e 's/firefox\-latest\/firefox/firefox\-latest\/firefox --private-window/g' /usr/share/applications/firefox-latest.desktop

    # En el firefox-esr del sistema (para todos los usuarios)
    sudo sed -i -e 's/firefox-esr %u/firefox-esr --private-window %u/g' /usr/share/applications/firefox-esr.desktop

    # Modo incógnito en Chromium
    # ---

    sudo sed -i -e 's/chromium %U/chromium --incognito %U/g' /usr/share/applications/chromium.desktop

}

# Comprueba si está activo el modo incógnito en los navegadores del sistema
# ---

function navegacionPrivadaCheck {
    # Nos limitaremos a comprobar que se cambió en el firefox-latest que hemos metido en el sistema
    grep -q "\-\-private\-window" /usr/share/applications/firefox-latest.desktop > /dev/null 2>&1
	[ $? = 0 ] && echo "True" || echo "False"
}

# Invocamos ("callback") las funciones asociadas a las opciones 
# seleccionadas por el usuario
# ---

function procesarAccionesSeleccionadas {

    # Dividimos (el separador es "|" ) las opciones seleccionadas por el usuario
    # ---

    IFS="|" read -a vals <<< $1

    # Solicitamos (una a una) que se procesen dichas opciones

    for i in "${vals[@]}"
    do
        aux=$(ejecutarAccionOpcional $i"Check")
        if [[ $aux == "False" ]]; then
            echo "Ejecutamos "$i"()"
            [[ $DEBUG != 'y' ]] && ejecutarAccionOpcional $i || echo "No se ejecuta "$i"() por estar en modo DEBUG"
        fi
    done

}

# Invocamos ("callback") las funciones "undo" asociadas a las opciones 
# NO seleccionadas por el usuario (las descartadas)
# ---

function procesarAccionesDescartadas {

    # Dividimos (el separador es "|" ) las opciones seleccionadas por el usuario
    # ---

    IFS="|" read -a vals <<< $1

    # Solicitamos (una a una) que se procesen dichas opciones

    for i in "${vals[@]}"
    do
        aux=$(ejecutarAccionOpcional $i"Check")
        if [[ $aux == "True" ]]; then
            echo "Ejecutamos "$i"Undo()"
            [[ $DEBUG != 'y' ]] && ejecutarAccionOpcional $i"Undo" || echo "No se ejecuta "$i"Undo() por estar en modo DEBUG"
        fi
    done

}

# Concatena el contenido de un array usando el delimitador proporcionado
# ---

function join { 
    local IFS="$1"; 
    shift; 
    echo "$*"; 
}

# Listamos opciones no elegidas
# ---

function getOpcionesDescartadas {

    # Preparamos las variables a usar
    # ---

    elegidos=$2
    opciones=$1

    rsdo=()

    # Procesamos los lotes de opciones
    # ---

    # Mientras queden lotes "de 3" elementos en el array

    while [ ${#opciones[@]} -ge 3 ]
    do
        
        # Obtenemos la nueva fila de valores

        row=( ${opciones[@]:0:3} )

        # Comprobamos si la opción no ha sido elegida

        valor=${row[@]:1:1}

        # Si no ha sido elegida, la añadimos a la lista

        if [[ "$elegidos" != *"$valor"* ]]; then
            rsdo=( "${rsdo[@]}" $valor )
        fi

        # Eliminamos la fila procesada

        opciones=( "${opciones[@]:3}" )

    done

    # Devolvemos como resultado la lista de funciones no seleccionadas
    # ---

    aux=$(join \| ${rsdo[@]})
    echo $aux

}

# -----------------------------------------------------------------------------
# Cuerpo del script
# -----------------------------------------------------------------------------

# Permitimos seleccionar opciones personalizadas
# ---

# Preparamos la lista de opciones a mostrar

opciones=("${opciones[@]}" `activarAutoLoginCheck` activarAutoLogin "Inicio de sesión automático")
opciones=("${opciones[@]}" `navegacionPrivadaCheck` navegacionPrivada "Navegación web en modo incógnito por defecto")
opciones=("${opciones[@]}" `accesoSSHCheck` accesoSSH "Permitir conexión por SSH")

# Mostramos las opciones personalizables

opc=$( \
    zenity \
        --list \
        --title="Elija las personalizaciones que desea aplicar" \
        --checklist \
        --column="Aplicar" \
        --column="funcionAEjecutar" \
        --column="Descripción" \
        --hide-column=2 \
        --width=500 \
        --height=250 \
   "${opciones[@]}" \
)

# Comprobamos que no se pulse el botón Cancelar

if [[ "$?" != 0 ]]; then
    echo "Sin problemas, ya personalizaremos Minino otro día ;)"
    exit 0
fi

descartado=$(getOpcionesDescartadas $opciones[@] $opc)

# Procesamos las opciones elegidas por el usuario
# ---

procesarAccionesSeleccionadas $opc
procesarAccionesDescartadas $descartado

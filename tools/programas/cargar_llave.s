// =============================================================================
// cargar_llave.s - Credencial y llave en registros, y la cabecera del buffer.
// CE-4301 Arquitectura de Computadores I - Proyecto Grupal I - Grupo #4
//
// Se INCLUYE, no se llama: son bundles en linea recta, sin etiquetas y sin
// retorno. Hace falta asi porque cifrar_archivo.s y descifrar_archivo.s
// necesitan exactamente este mismo prologo, y una subrutina de verdad obligaria
// a guardar R15 en la pila para no pisar el enlace del llamador.
//
// -----------------------------------------------------------------------------
// POR QUE LA LLAVE VA EN EL CODIGO Y NO EN LA MEMORIA DE DATOS
// -----------------------------------------------------------------------------
// Las ocho constantes se construyen con MOVI mas MOVH en vez de leerse de DMEM,
// y no es por capricho: load_file.py llena de ceros toda la memoria de datos
// desde la palabra cero hasta el buffer, asi que cualquier cosa que estuviera en
// la region de variables globales se perderia al cargar el archivo.
//
// Y ademas es lo correcto. La credencial son las cuatro palabras de ROT_SECRET,
// que es un parametro del hardware: es la contrasena del programa, no un dato
// suyo. Dejarla en un archivo de datos junto al texto a cifrar seria guardar la
// llave debajo del tapete.
//
// -----------------------------------------------------------------------------
// COMO SE ARMAN LAS CONSTANTES DE 32 BITS
// -----------------------------------------------------------------------------
// MOVI carga 19 bits con signo y MOVH sobreescribe la mitad alta conservando la
// baja, asi que el orden obligatorio es MOVI y luego MOVH, como dice isa.md 3.
// Los ocho MOVI van primero, de dos en dos aprovechando las dos ALU, y despues
// los ocho MOVH: eso deja cuatro bundles entre cada MOVI y su MOVH, mas que los
// tres que exige la latencia, sin un solo bundle vacio.
// =============================================================================

// Credencial: las cuatro palabras de ROT_SECRET, de la menos a la mas
// significativa, que es el orden en que las toma AUTHW
        movi r1, #0x3210 | movi r2, #0xBA98 ;
        movi r3, #0xCDEF | movi r4, #0x4567 ;

// Llave de 128 bits, una palabra por ronda:
//   9E3779B9 7F4A7C15 C2B2AE35 27D4EB2F
        movi r5, #0x79B9 | movi r6, #0x7C15 ;
        movi r7, #0xAE35 | movi r8, #0xEB2F ;

// Mitades altas. El MOVI de R1 quedo cuatro bundles atras.
        movh r1, #0x7654 | movh r2, #0xFEDC ;
        movh r3, #0x89AB | movh r4, #0x0123 ;
        movh r5, #0x9E37 | movh r6, #0x7F4A ;
        movh r7, #0xC2B2 | movh r8, #0x27D4 ;

// Cabecera del buffer: la cantidad de bloques de 64 bits vive en 0x4004, y los
// datos arrancan en 0x4008. El formato lo fija tools/formato_buffer.py.
//
// R13 es el puntero que recorre los datos y R12 la direccion de la rutina
// segura, que no cabe en un salto relativo. Los tres caben en un solo bundle,
// uno por slot, porque son independientes entre si.
        movi r12, #0x7000 | movi r13, #0x4008 | lw r9, #0x4004(r0) ;

// Los dos bundles vacios no son relleno: quien incluya este archivo va a
// saltar con JALR usando R12, y el ISA exige tres bundles entre el productor y
// el consumidor. Sin ellos el salto usaria el R12 anterior, que tras el reset
// es cero, y el programa se iria a la direccion 0. El ensamblador lo avisa.
        - ;
        - ;

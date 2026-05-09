# **Ingeniería de un Sistema de Traducción QWERTY a MIDI con Cuantización Escalar en Reaper**

La evolución de las estaciones de trabajo de audio digital (DAW) ha estado intrínsecamente ligada a la optimización de los flujos de trabajo creativos, buscando eliminar las barreras entre la inspiración musical y la ejecución técnica. Uno de los paradigmas más reconocidos en la producción de música electrónica y moderna es la capacidad de transformar el teclado de la computadora (QWERTY) en un controlador MIDI funcional y musicalmente coherente. Este concepto ha sido perfeccionado históricamente por FL Studio, donde la disposición del teclado no es simplemente una representación lineal de notas, sino un sistema estructurado por filas de octavas y restringido por escalas musicales.1 La implementación de este comportamiento dentro de Cockos Reaper no es una tarea trivial, ya que requiere una integración profunda con la API de ReaScript, el uso de extensiones de bajo nivel como JS\_ReaScriptAPI y la creación de interfaces gráficas dinámicas mediante ReaImGui.4

## **Fundamentos Técnicos del Entorno ReaScript y Extensiones Críticas**

Reaper se distingue por ser uno de los DAWs más extensibles del mercado, permitiendo a los desarrolladores acceder a casi cualquier función interna mediante ReaScript. El lenguaje de elección para esta implementación es Lua (v5.4), debido a su alto rendimiento, su integración nativa y la vasta disponibilidad de recursos para la gestión de tablas y estructuras de datos.5 Sin embargo, para replicar la experiencia de FL Studio, las funciones estándar de ReaScript resultan insuficientes por sí solas. La API nativa no permite una interceptación global del teclado sin el enfoque de una ventana gráfica específica, lo que motiva la necesidad de dos pilares tecnológicos adicionales: JS\_ReaScriptAPI y ReaImGui.8

La extensión JS\_ReaScriptAPI, desarrollada por Julian Sader, es fundamental para el manejo de mensajes de ventana y la interceptación de teclas virtuales (VKeys).6 Esta herramienta permite al script "comerse" las pulsaciones de teclas antes de que Reaper las procese como atajos de teclado estándar, un requisito esencial para evitar que al tocar una nota musical se active accidentalmente una función como dividir un ítem o guardar el proyecto.11 Por otro lado, ReaImGui proporciona un marco de trabajo de interfaz de usuario de modo inmediato que permite construir menús complejos y dockables que pueden integrarse visualmente en la barra de transporte de Reaper, cumpliendo con la exigencia de un acceso rápido y ergonómico.10

### **Arquitectura de Scripts Diferidos y Gestión de Ciclos**

Para que un script de traducción MIDI funcione en tiempo real, debe ejecutarse en segundo plano sin bloquear la interfaz de usuario de Reaper. Esto se logra mediante el uso de scripts "defer" o diferidos.5 Un script diferido utiliza la función reaper.defer(), la cual programa la ejecución de un bloque de código para el siguiente ciclo del hilo principal de Reaper, normalmente cada 30 a 50 milisegundos.14 Esta arquitectura permite que el script mantenga un estado persistente, monitoree continuamente el teclado y actualice la interfaz gráfica sin interrumpir el motor de audio o la respuesta del DAW.4

| Característica de ReaScript | Beneficio para el Traductor MIDI | Fuente |
| :---- | :---- | :---- |
| Modelo Defer | Ejecución persistente en segundo plano sin latencia perceptible. | 5 |
| Gestión de Tablas en Lua | Almacenamiento eficiente de mapeos de notas y estados de teclas. | 15 |
| persistencia (ExtState) | Guarda la configuración de escala y posición de ventana entre sesiones. | 5 |
| Integración de API C++ | Acceso a funciones de bajo nivel del sistema operativo. | 6 |

## **El Sistema de Mapeo de Octavas por Filas QWERTY**

El objetivo central es asignar cada fila física del teclado a una octava MIDI específica, permitiendo al usuario tener un rango de cuatro octavas disponibles simultáneamente bajo sus dedos. Siguiendo el modelo de FL Studio, el mapeo propuesto se estructura de la siguiente manera:

* **Fila de Números (123456789)**: Asignada a la octava C6. Esta fila se utiliza comúnmente para leads de alta frecuencia y texturas atmosféricas.  
* **Fila Superior de Letras (qwertyuiop)**: Asignada a la octava C5. Representa el rango melódico principal para sintetizadores y solos.  
* **Fila Media de Letras (asdfghjkl)**: Asignada a la octava C4. Ideal para armonías de rango medio y progresiones de acordes.  
* **Fila Inferior de Letras (zxcvbnm)**: Asignada a la octava C3. Destinada a líneas de bajo y fundamentos rítmicos.

Este sistema requiere una traducción de los códigos de teclas virtuales (VK) a índices dentro de una tabla de escala musical.17 A diferencia de un teclado MIDI tradicional donde cada tecla es un semitono, en este modo cada tecla QWERTY representa un grado de la escala seleccionada.19

### **Lógica Matemática de la Cuantización Escalar**

La cuantización de escala asegura que, independientemente de la tecla presionada dentro de una fila, la nota resultante siempre pertenezca a la armonía definida por el usuario. Para implementar esto, el script debe definir primero una "Nota Raíz" (ej. F\#) y un "Tipo de Escala" (ej. Menor Natural).22 Una escala musical se define técnicamente como un conjunto de intervalos medidos en semitones respecto a la tónica.24

La fórmula para calcular la nota MIDI final (![][image1]) para una tecla con índice de fila (![][image2]) se puede expresar mediante la siguiente relación matemática:

![][image3]  
Donde:

* ![][image4] es el valor base asignado a la fila (3 para C3, 4 para C4, etc.).  
* ![][image5] es el valor MIDI de la nota tónica (ej. 0 para C, 6 para F\#).  
* ![][image6] es un array que contiene los intervalos de la escala (ej. {0, 2, 4, 5, 7, 9, 11} para Mayor).  
* ![][image7] es la longitud de dicho array.

Esta lógica permite que la escala se repita cíclicamente a lo largo de la fila del teclado, subiendo una octava adicional si la fila tiene más teclas que grados la escala.23

## **Interceptación de Teclado y Gestión de Foco de Ventanas**

Uno de los requisitos más críticos y complejos es el manejo del foco de las ventanas de instrumentos VST y sintetizadores. El script debe ser lo suficientemente inteligente como para saber cuándo debe actuar como un controlador MIDI y cuándo debe permitir que Reaper utilice las teclas para sus atajos nativos.25 Si el usuario está ajustando parámetros en un plugin, el teclado debe enviar notas; si el usuario hace clic en la línea de tiempo para editar, el teclado debe volver a ser una herramienta de edición.4

### **Detección Dinámica de VSTs mediante HWND**

Para lograr esta funcionalidad, el script utiliza la función reaper.GetFocusedFX() y las capacidades de manejo de ventanas de JS\_ReaScriptAPI.4 El flujo de trabajo de la lógica de enfoque es el siguiente:

1. **Identificación del Foco**: El script consulta constantemente cuál es el identificador de ventana (![][image8]) que tiene el foco del sistema operativo.8  
2. **Validación de Clase**: Se verifica si el ![][image8] actual corresponde a una ventana de "FX" o "Floating VST".4 Reaper organiza sus ventanas de plugins de manera específica, y el script debe diferenciar entre la ventana principal del DAW y las ventanas de interfaz de los plugins.  
3. **Activación de Interceptación**: Si una ventana de instrumento tiene el foco, el script activa JS\_VKeys\_Intercept(key, 1\) para capturar las pulsaciones.12 Esto bloquea los mensajes de teclado para el resto de Reaper.  
4. **Liberación de Recursos**: Si el foco se pierde (ej. el usuario hace clic en el mezclador o en la lista de pistas), el script llama a JS\_VKeys\_Intercept(key, \-1) para devolver el control del teclado al sistema de atajos de Reaper.14

Esta gestión selectiva es lo que garantiza que el flujo de trabajo sea fluido y no intrusivo, permitiendo que acciones como "Espacio" para Play/Stop sigan funcionando globalmente si el usuario así lo configura, o sean capturadas solo cuando es musicalmente necesario.25

## **Integración en la Barra de Transporte y Diseño de Interfaz (GUI)**

El script debe vivir en la barra de transporte para proporcionar un acceso inmediato. Aunque Reaper no permite inyectar código nativo directamente en los archivos de recursos de la barra de transporte sin modificar el tema, un script puede emular este comportamiento creando una ventana de ReaImGui que se posicione y se "ancle" visualmente sobre dicha sección.31

### **Desarrollo de la Interfaz con ReaImGui**

ReaImGui permite crear interfaces de usuario de alta fidelidad con un costo computacional mínimo.10 La interfaz del script constará de elementos compactos diseñados para ocupar el mínimo espacio vertical, integrándose con la estética del DAW.10

| Elemento GUI | Función | Lógica de Implementación |
| :---- | :---- | :---- |
| Dropdown de Tónica | Selección de la nota raíz (C a B). | Actualiza la variable root\_note y recalcula el mapa. |
| Dropdown de Escala | Selección del tipo de escala (Mayor, Menor, etc.). | Cambia el array de intervalos utilizado en la fórmula. |
| Monitor de Actividad | Indica visualmente qué nota se está enviando. | Cambia de color o muestra el nombre de la nota en tiempo real. |
| Toggle de Estado | Permite activar o desactivar el script manualmente. | Llama a las funciones de interceptación y cambia el icono. |

El uso de imgui.BeginCombo y imgui.Selectable permite crear menús desplegables que se comportan exactamente como los controles nativos de cualquier aplicación profesional.13 Además, el estado de estas selecciones se almacena mediante reaper.SetExtState, asegurando que al reiniciar Reaper, el script recuerde que el usuario estaba trabajando en "F\# Frigio".5

## **Generación de Mensajes MIDI y Comunicación con Pistas**

Una vez que una pulsación de tecla ha sido interceptada y traducida a una nota MIDI mediante la lógica de escalas, el script debe inyectar ese evento en el flujo de datos de Reaper. El método más eficiente para esto es reaper.StuffMIDIMessage().17

### **Inyección en el Teclado MIDI Virtual (VKB)**

Al enviar mensajes MIDI al modo de destino 0, el script dirige las notas al buffer del Teclado MIDI Virtual de Reaper.17 Esto tiene la ventaja de que cualquier pista configurada para recibir entrada desde "All MIDI Inputs" o "Virtual MIDI Keyboard" recibirá las notas automáticamente, eliminando la necesidad de que el usuario configure ruteos complejos de pistas para cada nuevo instrumento.38

El script maneja dos tipos de eventos críticos:

1. **Note On**: Se envía cuando se detecta que una tecla ha sido presionada. El script calcula la velocidad (por defecto 96 o configurable) y envía el mensaje de tres bytes correspondiente.17  
2. **Note Off**: Es fundamental para evitar notas "colgadas". El script mantiene una tabla interna de teclas presionadas; en cuanto se detecta la liberación de la tecla física mediante JS\_VKeys\_GetState, se envía inmediatamente un mensaje de Note Off (o Note On con velocidad 0).17

Además, para cumplir con las mejores prácticas de desarrollo, se incluye una función de "Panic" que envía un mensaje de "All Notes Off" (CC 123\) en todos los canales si el script se detiene inesperadamente o si el usuario cambia drásticamente la configuración de la escala mientras mantiene notas presionadas.38

## **Optimización y Rendimiento del Código**

Dado que este script se ejecuta en un bucle defer de alta frecuencia, la optimización es vital para no degradar el rendimiento del motor de audio o la respuesta de la interfaz de usuario.5

* **Reducción de Llamadas a la API**: El script no debe verificar el foco de la ventana en cada ciclo de 30ms. Un intervalo de verificación de 200-300ms es suficiente para que la transición de foco se sienta instantánea sin sobrecargar la CPU.40  
* **Gestión de Memoria en Lua**: Se evita la creación de tablas temporales dentro del bucle principal. En su lugar, se pre-asignan las estructuras de datos necesarias y se modifican sus valores, lo que reduce el trabajo del recolector de basura de Lua y evita micro-tirones en la interfaz.7  
* **Cierre Limpio (atexit)**: Se utiliza reaper.atexit() para asegurar que, cuando el usuario cierre el script, todas las interceptaciones de teclado se liberen y se envíen mensajes de Note Off a todas las notas activas, dejando el sistema en un estado limpio.5

## **Consideraciones sobre la Teoría Musical Aplicada**

La utilidad de este script reside en su capacidad para democratizar la interpretación musical. Al mapear las filas del teclado a escalas específicas, se elimina la posibilidad de error armónico, permitiendo que el usuario se concentre en el ritmo y la estructura melódica.21 El script incluirá una amplia biblioteca de escalas, desde las fundamentales hasta modos más exóticos.

| Nombre de la Escala | Intervalos (Semitonos) | Carácter Sonoro |
| :---- | :---- | :---- |
| Jónica (Mayor) | 0, 2, 4, 5, 7, 9, 11 | Brillante, alegre, estable. |
| Eólica (Menor) | 0, 2, 3, 5, 7, 8, 10 | Triste, melancólica, clásica. |
| Frigia | 0, 1, 3, 5, 7, 8, 10 | Oscura, tensa, española. |
| Lidia | 0, 2, 4, 6, 7, 9, 11 | Etérea, soñadora, mística. |
| Mixolydia | 0, 2, 4, 5, 7, 9, 10 | Bluesy, dominante, rock. |
| Pentatónica Menor | 0, 3, 5, 7, 10 | Versátil, directa, rock/blues. |

Esta selección se presenta al usuario a través del segundo dropdown en la interfaz de la barra de transporte, y la reasignación de teclas es instantánea gracias a la arquitectura de tablas de Lua.15

## **Conclusión y Perspectivas de Flujo de Trabajo**

La creación de este script no solo replica una función querida de FL Studio, sino que la potencia dentro del ecosistema de Reaper. Al integrar la lógica de escalas con un sistema de gestión de foco inteligente, se resuelve uno de los mayores puntos de fricción para los productores que trabajan en movilidad o que prefieren la inmediatez del teclado QWERTY.1 La robustez técnica proporcionada por JS\_ReaScriptAPI y la elegancia visual de ReaImGui elevan esta herramienta de un simple script de utilidad a una extensión de nivel profesional para el DAW.6

El resultado final es un entorno donde la creatividad no se ve interrumpida por la configuración técnica. El usuario puede abrir un sintetizador, elegir una escala y comenzar a componer melodías complejas con la seguridad de que cada nota será armónicamente correcta y que, en el momento en que necesite volver a las funciones de edición de Reaper, su teclado estará listo para responder a sus atajos habituales.25 Esta simbiosis entre control musical y eficiencia operativa representa el estándar de oro en el desarrollo de herramientas personalizadas para la producción musical contemporánea.

#### **Works cited**

1. \[FL Studio Tip\] How To Map Typing Keyboard To Key & Scale \- YouTube, accessed April 29, 2026, [https://www.youtube.com/shorts/4JZxJmNPVfw](https://www.youtube.com/shorts/4JZxJmNPVfw)  
2. For anyone else who uses a typing keyboard, I made a keymapping for each of the major/minor scales : r/FL\_Studio \- Reddit, accessed April 29, 2026, [https://www.reddit.com/r/FL\_Studio/comments/14ut8s/for\_anyone\_else\_who\_uses\_a\_typing\_keyboard\_i\_made/](https://www.reddit.com/r/FL_Studio/comments/14ut8s/for_anyone_else_who_uses_a_typing_keyboard_i_made/)  
3. Keyboard & Mouse Shortcuts \- FL Studio, accessed April 29, 2026, [https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/basics\_shortcuts.htm](https://www.image-line.com/fl-studio-learning/fl-studio-online-manual/html/basics_shortcuts.htm)  
4. REAPER API functions, accessed April 29, 2026, [https://www.reaper.fm/sdk/reascript/reascripthelp.html](https://www.reaper.fm/sdk/reascript/reascripthelp.html)  
5. ReaScript \- REAPER, accessed April 29, 2026, [https://www.reaper.fm/sdk/reascript/reascript.php](https://www.reaper.fm/sdk/reascript/reascript.php)  
6. juliansader/ReaExtensions: Release versions of js\_ReaScriptAPI and other extensions for REAPER \- GitHub, accessed April 29, 2026, [https://github.com/juliansader/ReaExtensions](https://github.com/juliansader/ReaExtensions)  
7. Reascript tutorial \- From total beginner to working GUI-based Script \- AdmiralBumbleBee, accessed April 29, 2026, [https://www.admiralbumblebee.com/music/2018/09/22/reascript-tutorial](https://www.admiralbumblebee.com/music/2018/09/22/reascript-tutorial)  
8. js\_ReaScriptAPI/js\_ReaScriptAPI.h at master · juliansader/js\_ReaScriptAPI \- GitHub, accessed April 29, 2026, [https://github.com/juliansader/js\_ReaScriptAPI/blob/master/js\_ReaScriptAPI.h](https://github.com/juliansader/js_ReaScriptAPI/blob/master/js_ReaScriptAPI.h)  
9. JS ReaScript API Extension \- ReaLinks, accessed April 29, 2026, [https://www.realinks.net/links/js-reascript-api/](https://www.realinks.net/links/js-reascript-api/)  
10. ReaImGui \- ReaLinks, accessed April 29, 2026, [https://www.realinks.net/links/reaimgui/](https://www.realinks.net/links/reaimgui/)  
11. ReaScripts/MIDI Editor/js\_Mouse editing \- Slice notes.lua at master \- GitHub, accessed April 29, 2026, [https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js\_Mouse%20editing%20-%20Slice%20notes.lua](https://github.com/ReaTeam/ReaScripts/blob/master/MIDI%20Editor/js_Mouse%20editing%20-%20Slice%20notes.lua)  
12. REAPER API functions, accessed April 29, 2026, [https://mespotin.uber.space/Ultraschall/Reaper\_Api\_Documentation.html](https://mespotin.uber.space/Ultraschall/Reaper_Api_Documentation.html)  
13. ReaScripts-Templates/ReaImGui/X-Raym\_Basic ReaImGui.lua at master \- GitHub, accessed April 29, 2026, [https://github.com/ReaTeam/ReaScripts-Templates/blob/master/ReaImGui/X-Raym\_Basic%20ReaImGui.lua](https://github.com/ReaTeam/ReaScripts-Templates/blob/master/ReaImGui/X-Raym_Basic%20ReaImGui.lua)  
14. ReaScripts-Templates/Templates/X-Raym\_Background script.lua at master \- GitHub, accessed April 29, 2026, [https://github.com/ReaTeam/ReaScripts-Templates/blob/master/Templates/X-Raym\_Background%20script.lua](https://github.com/ReaTeam/ReaScripts-Templates/blob/master/Templates/X-Raym_Background%20script.lua)  
15. 27.1 – Array Manipulation \- Programming in Lua, accessed April 29, 2026, [https://www.lua.org/pil/27.1.html](https://www.lua.org/pil/27.1.html)  
16. It correctly handles the strange array/map duality of lua tables in the most e... \- Hacker News, accessed April 29, 2026, [https://news.ycombinator.com/item?id=41140351](https://news.ycombinator.com/item?id=41140351)  
17. Reaper ReaScript: StuffMIDIMessage Guide | PDF | Computer Science \- Scribd, accessed April 29, 2026, [https://www.scribd.com/document/926757013/API-How-StuffMidiMessage-works](https://www.scribd.com/document/926757013/API-How-StuffMidiMessage-works)  
18. accessed April 29, 2026, [https://raw.githubusercontent.com/Ultraschall/ultraschall-lua-api-for-reaper/Ultraschall-API-4.00---final/ultraschall\_api/Documentation/Reaper\_Api\_Documentation.html](https://raw.githubusercontent.com/Ultraschall/ultraschall-lua-api-for-reaper/Ultraschall-API-4.00---final/ultraschall_api/Documentation/Reaper_Api_Documentation.html)  
19. FL STUDIO Tutorial | Lock MIDI Keyboard To Keys, Scales, Chords | Stock Plugin \- YouTube, accessed April 29, 2026, [https://www.youtube.com/watch?v=lLEG6Ps0EBY](https://www.youtube.com/watch?v=lLEG6Ps0EBY)  
20. How to Use FL Studio's Typing Keyboard Layouts to Always be in the Key \+276 Presets (in Scales\&Keys) \- YouTube, accessed April 29, 2026, [https://www.youtube.com/watch?v=-HrpvQmACrk](https://www.youtube.com/watch?v=-HrpvQmACrk)  
21. FL Studio Tutorial | How To Map Your MIDI Keyboard To Key/Scales/Chords \#flstudio \#flstudiotutorial \- YouTube, accessed April 29, 2026, [https://www.youtube.com/shorts/jBhzwJaso08](https://www.youtube.com/shorts/jBhzwJaso08)  
22. Intervals & Basic Scales \- Theory and Sound, accessed April 29, 2026, [https://theoryandsound.com/intervals-basic-scales/](https://theoryandsound.com/intervals-basic-scales/)  
23. Scale Formulas, Patterns & Intervals Chart for Quick Reference \- Muted.io, accessed April 29, 2026, [https://muted.io/scale-formulas-intervals/](https://muted.io/scale-formulas-intervals/)  
24. I made this one page reference chart for intervals, modes, scales, chords and progressions., accessed April 29, 2026, [https://www.reddit.com/r/musictheory/comments/1ifjjpu/i\_made\_this\_one\_page\_reference\_chart\_for/](https://www.reddit.com/r/musictheory/comments/1ifjjpu/i_made_this_one_page_reference_chart_for/)  
25. If messing with a VSTi and "main reaper" isn't the focus hitting SPACEBAR won't play. Any way around this? \- Reddit, accessed April 29, 2026, [https://www.reddit.com/r/Reaper/comments/k2hezw/if\_messing\_with\_a\_vsti\_and\_main\_reaper\_isnt\_the/](https://www.reddit.com/r/Reaper/comments/k2hezw/if_messing_with_a_vsti_and_main_reaper_isnt_the/)  
26. Is there a browser event for the window getting focus? \- Stack Overflow, accessed April 29, 2026, [https://stackoverflow.com/questions/3478654/is-there-a-browser-event-for-the-window-getting-focus](https://stackoverflow.com/questions/3478654/is-there-a-browser-event-for-the-window-getting-focus)  
27. Check if window has focus \- javascript \- Stack Overflow, accessed April 29, 2026, [https://stackoverflow.com/questions/17389280/check-if-window-has-focus](https://stackoverflow.com/questions/17389280/check-if-window-has-focus)  
28. Is it impossible to know when your plugin is brought to the front or gains focus?, accessed April 29, 2026, [https://forum.juce.com/t/is-it-impossible-to-know-when-your-plugin-is-brought-to-the-front-or-gains-focus/44948](https://forum.juce.com/t/is-it-impossible-to-know-when-your-plugin-is-brought-to-the-front-or-gains-focus/44948)  
29. After Effects Scripting Tutorial: Detect Keyboard Input \- YouTube, accessed April 29, 2026, [https://www.youtube.com/watch?v=UBqdWdDmvao](https://www.youtube.com/watch?v=UBqdWdDmvao)  
30. Track/Mixer panel, tool bars, transport etc. scaling issue :c : r/Reaper \- Reddit, accessed April 29, 2026, [https://www.reddit.com/r/Reaper/comments/1r1zctr/trackmixer\_panel\_tool\_bars\_transport\_etc\_scaling/](https://www.reddit.com/r/Reaper/comments/1r1zctr/trackmixer_panel_tool_bars_transport_etc_scaling/)  
31. Customizing the REAPER 6 Theme, accessed April 29, 2026, [https://reaper.blog/2020/01/custom-reaper-6-theme/](https://reaper.blog/2020/01/custom-reaper-6-theme/)  
32. The Theme Adjuster for REAPER 7: A Comprehensive Guide \- Reapertips, accessed April 29, 2026, [https://www.reapertips.com/post/the-theme-adjuster-for-reaper-7-a-comprehensive-guide](https://www.reapertips.com/post/the-theme-adjuster-for-reaper-7-a-comprehensive-guide)  
33. cfillion/reaimgui: ReaScript binding and REAPER backend for the Dear ImGui toolkit. \- GitHub, accessed April 29, 2026, [https://github.com/cfillion/reaimgui](https://github.com/cfillion/reaimgui)  
34. reaper-imgui \- crates.io: Rust Package Registry, accessed April 29, 2026, [https://crates.io/crates/reaper-imgui](https://crates.io/crates/reaper-imgui)  
35. Dropdown Menu – Radix Primitives, accessed April 29, 2026, [https://www.radix-ui.com/primitives/docs/components/dropdown-menu](https://www.radix-ui.com/primitives/docs/components/dropdown-menu)  
36. Dropdown Menu \- Radix UI Primitives \- Mintlify, accessed April 29, 2026, [https://mintlify.com/radix-ui/primitives/components/dropdown-menu](https://mintlify.com/radix-ui/primitives/components/dropdown-menu)  
37. Using Reaper Action to send Midi CC to external devices \- Reddit, accessed April 29, 2026, [https://www.reddit.com/r/Reaper/comments/1pp33f2/using\_reaper\_action\_to\_send\_midi\_cc\_to\_external/](https://www.reddit.com/r/Reaper/comments/1pp33f2/using_reaper_action_to_send_midi_cc_to_external/)  
38. Reaper MIDI Controller Setup: Complete Configuration Guide (2026) | Audeobox Learn, accessed April 29, 2026, [https://www.audeobox.com/learn/reaper/reaper-midi-controller-setup/](https://www.audeobox.com/learn/reaper/reaper-midi-controller-setup/)  
39. Using MIDI in Reaper \- The Ultimate Guide to Get Started \- Reddit, accessed April 29, 2026, [https://www.reddit.com/r/Reaper/comments/1n2i2b3/using\_midi\_in\_reaper\_the\_ultimate\_guide\_to\_get/](https://www.reddit.com/r/Reaper/comments/1n2i2b3/using_midi_in_reaper_the_ultimate_guide_to_get/)  
40. A utility function to detect window focusing without false positives from iframe focus events, accessed April 29, 2026, [https://gist.github.com/tannerlinsley/1d3a2122332107fcd8c9cc379be10d88](https://gist.github.com/tannerlinsley/1d3a2122332107fcd8c9cc379be10d88)  
41. How to detect if window has focus in JavaScript? \- Stack Overflow, accessed April 29, 2026, [https://stackoverflow.com/questions/68665966/how-to-detect-if-window-has-focus-in-javascript](https://stackoverflow.com/questions/68665966/how-to-detect-if-window-has-focus-in-javascript)  
42. ReaScript: MIDI\_Compress\_By\_Pitch \- Indiscipline, accessed April 29, 2026, [https://indiscipline.github.io/post/reascript-midi-compress-by-pitch/](https://indiscipline.github.io/post/reascript-midi-compress-by-pitch/)  
43. ReaScript Basics with Raymond Radet Part-1 | The REAPER Blog, accessed April 29, 2026, [https://reaper.blog/2015/03/reascript-basics-with-raymond-radet-part-1/](https://reaper.blog/2015/03/reascript-basics-with-raymond-radet-part-1/)  
44. How To Play Notes On Keyboard For FL Studio | Piano Roll / Midi Tutorial \- YouTube, accessed April 29, 2026, [https://www.youtube.com/shorts/Nuwd1GLtWAI](https://www.youtube.com/shorts/Nuwd1GLtWAI)

[image1]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAABIAAAAYCAYAAAD3Va0xAAABGUlEQVR4Xu2TsWoCQRCGR7BRQRECYmkpCBZiIdgkWATsbJPeRhDyBNfaaKGVVlY2Yi15Ap/AvICdiI1NLEz+310ve3vkvKu9Dz5YdpbZmbk9kZioPMM9/NGuYcqIZ+GnEacrmDHOuCTgFJ7hN2x4w1c6cCneS3zk4Rz2Rd04EZXc5AO+WXs+qnAEi/AL7mDJiCfhTJ8LhDd19doRVVXPjYo8iaqYlQcyhDW9rsAj3MCc3mvCsV7/y20+vJWwjQW8wFe9x2pDz8ccLhMwERPyK0Wezw22xNbY4ouEmA+rYO91OwDeRQ19CwdWzIc9H5OCqKfAZHfnw7L53NN2QOPAAyxb+y4teJK/f4e/RdtzQsGnwH8vcD4xD8kvcTMzNIxbkGYAAAAASUVORK5CYII=>

[image2]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAcAAAAXCAYAAADHhFVIAAAAlUlEQVR4XmNgGHjADcSFQKyGLgECRUD8H4jT0SVAQASIHYCYFU0cN2AGYmMgtoGy4QBkxAQgrgXi00DciyzpCsQ1QMwHxAeAeCUDku5MINYHYksg/gbEETAJGAC58ioQTwFiRjQ5Bg8g/gXELkCsDsQNyJIzGCCOEWaABATIHXDgB8RPgHgDEBcwYDGaB4gF0AWHDgAAPfUSVNIdKk0AAAAASUVORK5CYII=>

[image3]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAmwAAAAiCAYAAADiWIUQAAALlklEQVR4Xu2cV4hsWRWGlxgwjTli6pExMeYwYBb1yogoYkDB8DIYkEFRGcMI2iZEBTFhxvAwDIo+yJgRLFTEhL44KDOKVxFllFEQFFQM57v7/LdWr95Vdbq7bnV7+/9gU6f22afODmvv9Z+1T3eEMcYYY4wxxhhjjDHGGGOMMcYYY4wxxhhjjDHGGGOMMcYYY4wxxhhjjDHGGGOMMcYYY4wxxhhjjDFr4jpDun7NNMYYY4wxR4Pzh3TNkG5STxhjjDHmeHPzmnHMOErtv320CNtx4XZDukXNXAObHtNzasYR4YZj0nGGfr91yTso143Dsd8bR7v3VG4wftY+OSrQh9WmaKO4aTo2xhwTcGwX1MxoC8ZTh7Q1Hp/N0P5NO/jjAIJgle38YEgX1cwDssimD8oyYfm2mrEB2DZfJTiYwyT4/JDuls7R759L39fB22vGhnjrkO5YM5dw4fipvtk0COVlcwNBVm3qA+mYccxjaYw5RJ42pP+WvO8N6d4l7yCcGNKs5OHsfhhNqOn7N4d0ZxVYAAv1KuexSZ4zpE8P6Tcl/wtDesCQfjqkZ6T8K8r3dfCJIT1qPObp/9+xfJEGImy/GtJt6ok185BoDvx6Ke8dsfupfr/cfUh/qJkdPlO+Y/MvKXl7ZVYz1gAO9ic1M1GdK9A2jT88OHbb40Fgzq2al1mwYXsfTOegV+/9wnb+uen7y6LZfB5jROabhvSiIf0t1ic6eoKNuXRl7J5LD0/HPcGGWMJ2sWFg7j5lSA87XeJg8LuX1szCKsEGjOVrS54xZsPw/hLOngn53JT/qnS8Dq4e0n3SdxZ0FtgKC8yXa2bh7zVjzdyqZsS07ZfsIBEpiCFtOyIOnjyeo42/HI+XUQXGIujXa2OnIKKPqvNYJ9Rt6lZJFpN3iuY46Z91gZjYj2A7KLQh2/S6oF9nNTNRnSv8Nebj/8Dx833j5zqY0r9ZsMEth/S89L1X70pP1FSwoatqZrT5l8cYgYHtAWKT+Vhhbvbm9bL3OnuCbRGfSse9trEmKFJ4o2h1YfxZN9YBvy0xuIgpgo2x/FHJM8ZsGCbzx6M9CX4t2qIB+Wl9HXwndkZUHh3tfhXqM0vfWcCeHs05sk3EQolz4n0kvUfCk/RDx0/BMddQhpTFC5G8J0V/oYZ7xO6n8TfG4vIiCzbuwWItUYNg04KNMyCSuIqpAqMXIa3fae89Sx7Oojoe+kzt7AlXsRfBxkKPk4VLot136/TZxuOijXOGMSTvLiXvMek7IPCryK/2ALk/ZRsHgehctmlshjEm+ssnkTLuQRu25sVO8ezYXQf6/VnR+n2W8ivVuUIeb4mUGsXFBqhTBmFQ+5PxyX0O/yzfQQ8gogo2uCwd9+pdqdf3eGL0xVcVbNjAi8dj7DzPT4HIfWXJQ4TX+Z/pCbbaF+IN6bjXNgQV8xf0EJPfBQTqU21FcyNDe+tYMi/yb/XWyimCDbCrVWugMeYMsh1tAQQWfSJtLBA5WpNBZP12SerBgqCnSMB5n4x+dAInqEWeheU10bY+fhdNdJHeP54H3h9iSxK4hxY9nuy5hqdsHKAWcn5vazxGSCwSHUQpvh5tYZsi1qDnEID6cd/8G9Rr0b1Fdj7LmEVzqHwyhh9O57gn0U3gKXkWTZR/JJqjyNFK6kkk4t1D+lnK70HdVtVfUCfZR3UgIOHOQwPjT51fHW1sifpKjFwT87Fmi0tjTdtlw1xDOcAeKCfUnyeGdLMhfTb2L9p6UTC2sehP+pd+xP7OizaX2BLmGu79l7E8tsV7XZRH3PN6ACCq9rIlyrgSraZ//xjzvhCIsh+Px5TjPILkY9Hq8P1oc5Hjb4/leHBSdIjxyoKY61SOyJvK9QRbnhO13j3q9T0YR/qzwr16c4Z2UcdF7xpyngcJ7I52LhNrkAVbnkt5+xNYtzgvatvoY/pPc+PanadPcXE0+2GMqBt1/FPM54bWQtk8ZJvPQruulSo3VbBR/ypUjTEbhOiaHOh2NOf4ztNn1wMLQn7/AUfLYlEdvvKJnuFU/rPz9Clw6Fno5TIIMIkiLXJ6wV9O7F/jJ/wjHfdgIedJnoV1Cj3Bxv1fUTOj9Ufd9iDyhjNU+nX5vgjGTFvY6kPBgq5oKZ96mgcExXb6DneIJjIqvbrhBPX9onnRHSAmcjRE4yAnD1dEa4OcC3XO4wRcJ9HPb3I9Yy0xIRvGHlQOe8j3yc58O3a+A7VXeoIt932N6Ejg0hezlI8dMHa0X3Ok99uZ6lx5ONH4Y1P0Bc6c97qA+YQA5x5EtgFxwBwR6kfZOr8pQUzfa9wol9+5ysK5J9iIhotab3hE7LSrb6TjRVu69GVPmC0SbIhfxPQyeDj8fUx7MOtF2JhLGfqJtTVT+wY7ZUzEm8fPHJV7abQyn4wm/vJ8Fr25AVVo17VS5fYi2Hgn1xhzSGghBhYrImy9p1fxhGjbNotSDxyDtmkAEYOYqkIIJ00kCnBAWXjAbaO92AvvibbQZIdAdIMnyGdGcyJaIPXkS3ltRVIntmnfNaS7jnkZokyXjMcIxFVP3VAF23tjvi3FgpidBgvssvdkoOd8KufE/F05YEGXE5Dj5z60l3El2kh7WfwldO43lj9vPA/nx/LokwTIKrKYEESQ7jseY38vH48pSwSVMZqNeUA9EDNyFpSjLxlriYnHjuewB5XDHiiHPUDuT8ThvWK3YJ2K+jMzRbBdHjudO3ZAXyCgFC3Zi2DTu0VV/ONwJT6Iql04HmvMs1AAIoKqr36TT8Qe1/A6AmNDuzSXOX/Z+EnEsifYslivoqBHvb4HfdZ7paAn2PIYLXroIZqu+U00XfN+EVWwaS5dGvO5xG/khyOobUP41nbw2xePxwjNr47HtA07p3yed/z7jd7cwOY1N/QwVddKlZsq2PjtamfGmA2BALp/ydO21LqRoxAsZq9P318YLRIlkYDzU5gfx8P5B0VzbHyXEPrz+MmCy6LGQoPAYgFTmQ+Nn1w3G49ZqFjc2c7I9QIia7zXIocH1H8V2RHzG0TwtN1xMuYCld/F0a2iOp8eOHucEgIC2GKTMz4RTYCzINNeHPe5MRdpLMBb0RwO/XfVkD4aTUBxvAwJkGXQTp7ic0QAe2PrT/VFzD0y2rgzFlyDA9KWIGKTOiE4FMmhbrxjxVhzPUIT4Q3YA+VkD5RTRDb3J4KEa+mj/YLAyraDA9QWc0+wIXiwYdkswpW+oM2Ie4kb+gPhpz6qZOcqkZjLvi52bs/9Itr7i4zX88e8q+en4/HRXlNga5q68NCEDfEbOGjqhZ1xD23fqhxjpXv1BFueN1UU9KjX92B9urJmRuvvPK+IFtPXmoOL/q3Il9Ix83bVKxBVsGkuERHUFih9VMVNbRt9rMgYYA8nYx75pe7UBb47nqe/+QTmxgtiPjc0h2Xzmhsan7pWqtxUwYYgrWulMeYsBKdRQ/ksjkTleBl6ESyMefHkuAoFFjDyWUxyWcrVRRNhoOuX/a+rMwkL6M9rZocsMPYCbc5ChCiJyH2HgGAMgEgdqB9XQd3qOOwXxk/1yGSnCPmfr2rMgfblaKD+JxvtUHnI/bmOuuNYq01PhTouajN1z/WuVOe6Cvqm9hFgJ9k2lAfZDuqco94qRz1Vrgo2+icLxyn1rqKmhyL0h0UVbMBcyvTsYkrbKvR7tVX98VXN03zItlPHN6+VKjdFsDGWU9YsY8xZAFsu36qZxxS2NbQFYzbHfgXwMg7DpqtzPSpkwYYY+Eo6B+usNyLjINHRg9ATbBltP1f2I9g2wRTBxlheUPKMMWcxTHj9EcBxheiEtmrNZjkTgu0wbLo616NCFmzb0f7SN7Puen+xZmyIVYLtLTVj5P9VsBGRYywVwTPGGGOMMcYYY4wxxhhjjDHGGGOMMcYYY4wxxhhjjDHGGGOMMcYYY4wxxhhjjDHGGGOMMcYYY4wxxhhjjDHGGGOMMcYcLv8D/m7wEMQAV0gAAAAASUVORK5CYII=>

[image4]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAD0AAAAYCAYAAABJA/VsAAADeElEQVR4Xu2XWchNaxjHH6HMjsgUiaR0lGQoMpQQF2aF1Ol0SoQLQ5IhfTeSwgWKdGQoScSFMl98RR1xRUQciUQIpbhR+P++Zz32u9daW1yZ9r/+7bXe5x2e+V3brI46flt0FieJc8SBYvNq8a+DZuJY8ap4RlyQ8bx4TxxemfproKW4RXxgReOQ7RVfi0Nysq8BmXJNHJMXfE9g1G7xlTgiJwug+Etxl3lGfAsWma9ljx8Gi8UP2W8tdDKP1i2xS072JeCgw+Zr2eOHQH/xiXhb7JaTpQijH4o9cjLA2qnmPYHMgYz9Kd4R95uvaxcLMtAgyQCaZtucDCAfapV9AY4cLPaJSQmYM8yq5xfQIH4UN+XG8+gnPrWi0d3F4+JJcZ640bzxjRL3ZM/szy99YZova8IA8Yq4WfxLbDQPwMpMjtLbxNXZPJ4BBr8RL1q1o8aJN8RV4lLxP/M+NCWZ0+T1RvPUnpAKSoCceZfE9tkYnr5pbgwKdjRXLq3fWvXM2rviWqv0CG4KHBSOmShuMM8y9j2YjbcWD5jrHplDL3omzs3eAYF8a54pn0HEiFyZUnnsMFeoIXtvIf4rPhb7JmP/iDPMDalVz2VrARFOdVmYPY8U35lnUmC0uDN7juDhGBwf4IxCDwqj8ymbR2/ze/qFeY2C6OakNkaUgcM4FIelKFvLL++NVqz7Bis6aJZ5FoHIwrREowfRS6pum1DqS0azgBQkytRKgKbFWNRfGbjviRBpmyLWhtKApnffig4K5VMHoVODVTJijRVLNOo+PaMJbHJEfG+eLmWgVmgGUbcBmgOKY0Aebcy7LgdyMAqA+eJ0qxidNhjORw8iSDqvyMYjGzEsQMS3WsUJyNJzAI7G4TieOp+dyJq+sDCKNMi3+PHic3G7efNIESn/d26cNSfMv92JWtQzjYsPIGpukHl6R8NijE4cTWe9VaIWGbAue0fHLVb9ZTjZ/MMqGlY0SZyFntR+oWfhjf/Nv7nje5tvb9o/RlTVRAIiRa0dM8+ERvPrp0MmJ3pcc0fN07NXNs5+y8Tr4j7xgjjT/CY4Z341pXfyEvPOfEg8a94oUzCXyF827/CnzCP7SDwtLrcaNsRHAv+qSL+eVmNiDhxINLpa+T+xVlZbRsNKZexFnymbyz6kOr+18Id5hoXezE3f66ijjjrq+CnxCQ4VtGvmuq87AAAAAElFTkSuQmCC>

[image5]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAACoAAAAZCAYAAABHLbxYAAACoklEQVR4Xu2WS8hNURiGX6EIueZSLr+SS8jApdwGBpQBEwMDUVKMGBByGbgkoRQpRMlISTGgkIFSImVEymVAJEpGFBLv07eXs//173NwfunU/7/1dPZZa++1vrW+91t7S/9fK8x3szHvaCVNNe/MOdMv62sZDTQ3zDbTM+trKfUwI4rfrqNF5q35UeK9+aoogPuKYuhM6uabtaZ33tGMzppvZkGpjeDWKwLGZ82kkNS/MI/NsKzvrzXA3FEMyMBljTIv6/T9iVjcPDMu72hGU8wHc8n0yvpmm8/6RzvSWS1XeHND3mHtUfRtydoRx88SM1HVthhqliqyUiWsNdPMUO35yWbIrzsyHVdHf2L8dYqd3lr8L/fh2XtmlTlqHpqnqtljlrls9plXZlLRntTfXFStgPcrsneq6OsgGm8rqvxucf1E8fBJxa6UxcoJ8plpK9oGmweKZxmvr2LCCYpsYZ25xb1JK81eM9pMM0fMIzXwcpU/CWaHotoXF21JpOqTwhJJqbLJDBpjdil2/oJi57FJPZFqTh1iqavkz81ZewqIAcqqsgnXXxRjlTXevFb7ReUaqZiD3W+oqokR3mMBB0ptySb5CcAiyUq+IxTnR0Vqq0RwfKyQ/oZqdH6yAALdXmpLgd5S7UsIu2AbxiGFh81YhU+vm2umj9lpphfPIILEx+UK50vrkCregqyUFefnJ9epIlOgeA6/nlCtaFD61jyvSDWTExhBMTaZaTPHFMEjCoYT4o05XdyzqWhrVxMLFW+b/P1e9lgKgIBXmzOKiUgTu8firpiDZrd5bq6aOTysWMjNAu5L1UyBsRjeVmSF1DM/p84aVZ/HvxV2WKZYZdoNRGqGq/15Nyj7j7gPL5fPYNqwXBKBcQSShW51q1tdWj8BLj6HXRmsN44AAAAASUVORK5CYII=>

[image6]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAADwAAAAYCAYAAACmwZ5SAAAC+0lEQVR4Xu2WS6iNURTHl1Dej7xDHpkoIkopUaIYKMlAMZABZSIGGJmJiSQZkNIlkXehxEQGIgYSE49CoshEGXj7/87a6559vnuOe851u+7g+9W/e89ee+9vf+u1P7OSkpJeQH9pnDSgaGiVldLvJrUjrelJBklnzZ//S1pWa+46bdJ3aVFhvI80T3otrSnYepK90ltpUtHQFUZKD6RX0sRaUzvHrRu92yKk8fWkf05pmCN9li5I/dIYf+ea1w4cSvP+B9Ol9+ZR7hbWm9fIrmyMSBPVwek36Tyiaq5Auk+VVkuLreqcIjSbVdZ4DnZ6yeSiIUFmfUt/69HZ+g7wYj/MDz5BmiIdtb97lIMfkc5Ia6U90kVpYDZnvHnWXJbWpTk3peHJjjPZ42qy00eepjnhaOAcRJhI5zS7voao35/mTeGN9CH9buRRWCHdNV9P+vPiPGx0suO0J9Ixc+fwkvekT9LMNIbtTrJBpO4J8+yBRvXb7PoOzJe+WG39DpXOWdWjfdNYDun/VdosjZJmJwH7kDU4cFo2tsk8izgMJYJTiUwQvWRLNtaofptd34Go3/yOpSYOW9WjbLq1aq6w3PyBcUffksYkGxEkkrkTcyJqxTTlLDifIAT16reV9TXgacJf7/4NhkinrBqpnBnSTvPUzZ1Ggyo6MYc+wb1eTFOyIi8LqFe/rayvIer3pXlU67HBPNpREzQlmtMzaWwai30ileLrjRcvwpcTHw8cmAMGscfp9P9B8/2jfrkh9pu/TLxwZ+uHZfYK9eo3oMvtlj5KC7NxHPPcPDOiI3NfPzKPOHA9MGdj+h0slS6ZX3k3rNpcEJkSVyPP22f+LIJBlGeZd2TOyXObWd8O9fAuTUB5h0bUTNjYOL9q2Hy7uTfpkm3SfWlJNgeIMnueN5932/wQ4XWc9Fg6af6MbeYReyhdMe/yPOuA9EK6Ji2orHSaWd+tUDukVvFjJIergyiRmnT6ImGPOuQF6fh5XcYYvaRIM+tLSkpKSno1fwCbd7rLkVe82QAAAABJRU5ErkJggg==>

[image7]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEYAAAAYCAYAAABHqosDAAADNklEQVR4Xu2XS6iNURiGX6HI/ZJLyZ1yKcp1QJ0BYsCAiSKXdDBWJBmckoiipEgkAxMJAyQZ7GKgSBSRy4CUIowoJN7X93/+tdfZ/7H2j12ns9966uz1/eu/vGt937cO0FRTZdWPdI8Hu4h6kj7xoGsPGRkPdiJpUYeRvnEgQbPI1njQVWTMcPKC/EjgBjpw/j/qIPkOe4ctUSxFpYxxLYc9eG8coIaQc+Qs6RbFGqU15DOZEwcS9FfGyBAZsyIOZJJxR+LBBkrPfkSGxoEElTZG6aE0eUPGB+OTkL+IjNkWxBqpQeQOOU96RLEUlTZGZsiUCvLippQ5TGZkv2dmxBpAlsCMU8rVUi/SguJr/B6TUTtVp5D3KK4vf5pf2phlsDQ6CrtGrIcZpdUq0krYSq4jG8htMi2Iq01uJ/fJZrKR3CXzg/gO2DzVkEPkHnkKawouxb6RBcGYlDq/tDFeX96SV+Q1rAt0VFP0YH2kv+xq2JxF2W+99DHymIzJxtqQdxatrD7qGRmbxT1lKqhuy7XqSz3zSxmjG1TQvr7sgq2CKz4g6mGfyCkyAWZUC8wQSbtJRskw1zzYDlJN8/ltQdyPDuGCFNWX1PlSKWO8vsRnlP2w3JbGkZOkdx7+ddh6iPyM844szGKqKVfQ3uxQevk4PfT3F1R3xqL6kjpfKmWMblJ0fnFplcOVd/Una8lFVB8A9ZyXwe9Yvkvj9FDXkwm+IFKt+lLPfKmUMV5fVIBraSK5jupi1gpLk6XBmO6jXaLd4lv6TBB3KdUGwz4sNE5ponS5mcUPkNGori87YcXdjUmZL9VtTFF9kVRPFpPnqM5jSWn1BNYeJd3nGmz3SHpJXaOd5DVHGkEuwFJOHbCCvEiugpktM5W6x2GtXR+vDx5FTsNaswpvynwtkpRsjOqDnP2KvEZ4RxIfgvGPZLpN+63Z5AHsJU7A2qXSLTRBH3IL9hxdI0Nk1NQgrpg++hLZR3bDFuIymZtdp92phbsKK+iu1PlSsjH/QtpRMliE3SqUVlarruf66oXye4StdWD028dErNT5DTWmM6lpTIGaxhSoQ2M2ofY/cF1B6p7xoa+ppurQT+4l0aP7qThLAAAAAElFTkSuQmCC>

[image8]: <data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAEkAAAAYCAYAAAC2odCOAAADl0lEQVR4Xu2XS6hOURTH/0J5JpFHKHRTQshrwuAWxcAjZSApZUC5GYgUBp+QMPIWSkgoJUUJgw8TYSrKwEeiCCWUt/W/6yzW2d/e56iLDM6v/t3v7nXO2XutvdfaewMVFRUV/y+topei706vRUtF/UXXRV+d7Z3ojKinaFdg4++1os6iA4HtE/SbpEX01NleiMZlNmM5tC97Zp+ok7MPFT1wdmq3sxP69jyzed/Yn43pomiUvVDGUdE30czQAG2j7RjyAyWTRO9Fl0XdA9sU0QfRKTS/10N0XjQ/YjN6ia5AnWFQR+TN7WwQbYdOTAr69lk0PWhnoC+I3oimBrYm+oruiBqiIXlTO+uhkV8SGoSR0NmqQ53yWJDOiboEthmirUgHiPDbR0Q7of235c3t7EWz857eopuie9DMCBkouo/4JOcYLXqFuDP8n+2087mQwaLH0IFwQEZX6Mqjc3XkA8jBMDWGu7YYc0TrRGOhs31L1MfZOblnoY6mKPLNOI60fz/hCqEzXDEhXFkN6ErjoEI4O5wlBooBM2aJDkPTpI58kBZAa04ZNWiq07nT0JSf7ex06mBmTzEP6tuK0OBgkLjiufKT7BF9gQ6ejnotgg6Oz8Sg83Xkg8S2Q9A8Z7u39YMWdf4tghsDa4mlP4PDcTBYFhRO7prsdwqOO1aPDPZzDVpXWV+jWD3iQyegs+/1COl6RCxIb0XjszY+S8UCuBo6GWVYPeqW/c80Y7ox7Zh+ZAfSzhPrP1WPiGUK6yr7jFKUs2X1yOBytZkYINoPHWAYwBboCisskBlWjzxt0Amr4c/VI6YzV+gl/JqQJqwexZZtWT0yGCQuae5Ym6D1iLBTds4AThZtRsGSDqih+TjCIwBrHHejVnS8HnFn5fmLQVoY2HKkzhCEbbSl6pGxDTqYjdDtmjubYUVxFTRIHFgZXIEnoecYD9/dAu3rLtLOG2X1aCI0fVlW/JhzdOR85LHneAIeE9gYJNoa0HT7HcJ65GE9omNFzpOy89Eg0Q1o0fbHiibstBzLWUsVX5BTMFUZCM5yuFIsgLHjRQy+vwy6A4bfInYcSDlvWDBD37hiuHE0oNerZICY68+ggzfxPrMYujVfhV4FzMbfvFrwKhFjruihaFhogAbnNsq3fLIS+X45xgm5JxQeB/xRwMO6yN3UvsH7I+vYE6iPH6H3tWmIT8Jfg6kaXlAN2op2xoqKioqKiop/wg/yWfVOa50cKAAAAABJRU5ErkJggg==>
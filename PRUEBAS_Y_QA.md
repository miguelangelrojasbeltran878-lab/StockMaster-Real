# Informe de Aseguramiento de la Calidad (QA) y Plan de Pruebas
**Sistema de Gestión:** StockMaster  
**Versión del Software:** 1.0.0 (Release)  
**Entorno de Persistencia:** Firebase Cloud Firestore & Auth SDK  
**Desarrollador / Evaluador:** Miguel Angel Rojas Beltran  

---

## 1. Alcance de las Pruebas
El presente documento certifica la validación funcional, estructural y de seguridad del ecosistema **StockMaster**. Al ser una arquitectura móvil serverless orientada a eventos con Firebase, el aseguramiento de la calidad (QA) se centró en garantizar la integridad de los datos en la nube, la respuesta reactiva de la interfaz en Flutter y el aislamiento estricto multi-inquilino (*Multi-tenant isolation*) para que las empresas no mezclen su información.

---

## 2. Matriz de Casos de Prueba Funcionales (UAT)

| ID Caso | Módulo | Descripción del Caso | Resultado Esperado | Estado |
| :--- | :--- | :--- | :--- | :--- |
| **TC-01** | Autenticación | Registro de empresa nueva con credenciales válidas en la pantalla inicial. | Creación exitosa en Firebase Auth, generación del nodo en la base de datos y entrega de un código alfanumérico único para invitar empleados. | **Aprobado** |
| **TC-02** | Autenticación | Intento de registro o creación de cuenta con una contraseña débil (ej: `123456`). | Intercepción local por la lógica de la interfaz en español. La app detiene el proceso y exige explícitamente: 8+ caracteres, una mayúscula, un número y un símbolo, impidiendo peticiones basura al servidor. | **Aprobado** |
| **TC-03** | Autenticación | Inicio de sesión (*Login*) con credenciales previamente registradas. | Verificación correcta en el servidor, persistencia del estado de sesión en el almacenamiento local (`SharedPreferences`) e inyección del rol correspondiente en el sistema. | **Aprobado** |
| **TC-04** | Inventario | Registro de movimientos de stock (Entradas y Salidas de mercancía). | Mutación atómica del campo de existencias reales en la base de datos y adición automática en la colección de historial de movimientos con fecha y hora exacta. | **Aprobado** |
| **TC-05** | Configuración | Eliminación/Borrado de un empleado del equipo por parte del Administrador de la empresa. | Remoción física inmediata del documento del empleado en la ruta específica de Firestore. La interfaz se redibuja de forma sincrónica desapareciendo al usuario de la lista. | **Aprobado** |
| **TC-06** | Reportes | Filtrado y generación de reportes de Stock Bajo para exportación en formato PDF. | Filtrado matemático exacto de los artículos que cumplen la condición de alerta. Compilación limpia del documento PDF listo para compartir o imprimir sin desbordar la memoria de la app. | **Aprobado** |

---

## 3. Pruebas de Integración y Contratos de Datos (Postman)
Debido a que Firebase Firestore utiliza conexiones de sockets asíncronas en lugar de una API REST tradicional, se utilizó **Postman** de forma estratégica para documentar y validar los esquemas estructurados de información (JSON). 

Esto asegura que las estructuras que Flutter envía y lee desde la base de datos NoSQL mantengan siempre el mismo estándar y no rompan la aplicación.

### Estructura de la Colección Exportada (`StockMaster_Pruebas.json`):
1. **Contrato de Empresa:** Atributos obligatorios para inicializar un negocio en el sistema y generar su código de acceso.
2. **Contrato de Usuario:** Estructura que define el perfil de un empleado asociado obligatoriamente a una llave foránea de empresa (`empresaId`).
3. **Contrato de Producto:** Formato de datos con tipos estrictos (código de barras, stock actual, stock mínimo) para garantizar la compatibilidad con el módulo de escáner QR.

---

## 4. Certificación de Seguridad y Privacidad
Se certifica mediante este plan de QA que **StockMaster** implementa un aislamiento robusto de la información a nivel de código. Un usuario perteneciente a una "Empresa A" no puede bajo ninguna circunstancia listar, modificar o eliminar productos de una "Empresa B". Todas las consultas se encuentran restringidas y parametrizadas de forma obligatoria mediante el `empresaId` cargado de forma segura al iniciar sesión.
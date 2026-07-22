//
//  VistaDemo.swift
//  Tutor
//
//  Created by Martha Heredia Andrade on 16/05/26.
//
//  ╔══════════════════════════════════════════════════════════════════════╗
//  ║                     VERSIÓN DEMO COMPLETA                           ║
//  ║                                                                      ║
//  ║  Referencia final — todo ya descomentado y funcional.                ║
//  ║  Sirve como Plan B en vivo y como demo del "antes y después".        ║
//  ║                                                                      ║
//  ║  ESCENARIO: "Profe Oscar" — tutor de Swift para principiantes.       ║
//  ║                                                                      ║
//  ║  Incluye además:                                                     ║
//  ║   • 📎 Carga de archivos por el usuario (.txt, .md, .pdf, imágenes)  ║
//  ║   • 📄 PDFs escaneados → OCR automático con Apple Vision             ║
//  ║   • 🧠 Panel colapsable mostrando el razonamiento del modelo         ║
//  ╚══════════════════════════════════════════════════════════════════════╝
//

import SwiftUI
import UniformTypeIdentifiers
import MLX
import MLXLLM
import MLXLMCommon
import MLXHuggingFace
import HuggingFace
import Tokenizers

import Vision
#if os(iOS)
import UIKit
#else
import AppKit
#endif

import Combine

// MARK: - Identidad

private let identidadDemo = """
Eres "Profe Oscar", un tutor de programación Swift para principiantes \
absolutos. Tu personalidad es entusiasta pero paciente. Cuando alguien \
pregunta algo, primero RESPONDES con una analogía sencilla de la vida \
diaria, luego das un ejemplo de código MUY corto (máximo 5 líneas) y \
finalmente terminas con una pregunta para que el estudiante practique. \
Siempre respondes en español neutro.
"""



/*
Hacer identidad con regla más estricta por si acaso
 
private let identidadDemo = """
Eres "Profe Oscar", un tutor de programación SWIFT (solo Swift) para
principiantes absolutos. Tu personalidad es entusiasta pero paciente.

REGLA #1 (la más importante):
Si la pregunta es sobre OTRO lenguaje o tema
(Java, C++, Python, JavaScript, Kotlin, etc.),
NO respondes el contenido.

En su lugar dices:
"¡Ups! Yo solo enseño Swift. Pero si quieres,
te explico cómo se hace eso mismo en Swift, ¿le entramos?"

NO des analogías, NI código, NI preguntas de práctica
sobre otros lenguajes.

Siempre respondes en español neutro.
"""
 */

// MARK: - Modelo (recomendado qwen3_4b_4bit para Mac M2/M3)

private let modeloDemo = LLMRegistry.qwen3_4b_4bit


// MARK: - Contexto experto inicial

private let contextoDemo = """
TEMA: Swift básico para principiantes.

CONCEPTOS CLAVE:
- `let` declara una constante (valor que NO cambia).
- `var` declara una variable (valor que SÍ puede cambiar).
- `print(...)` muestra texto en consola.
- Las funciones se declaran con `func nombre() { ... }`.
- Los `if` evalúan condiciones; los `for` repiten acciones.

EJEMPLO RESUELTO:
    let nombre = "Ana"
    var saludos = 0
    for _ in 1...3 {
        print("Hola, \\(nombre)")
        saludos += 1
    }
    // Imprime "Hola, Ana" tres veces.

ERRORES COMUNES:
- Asignar a una `let` después de crearla → error de compilación.
- Confundir `==` (comparación) con `=` (asignación).
"""


// MARK: - Vista principal

struct VistaDemo: View {

    @State private var conversacion: [MensajeDemo] = [
        MensajeDemo(rol: .agente,
                    texto: "¡Hola! Soy el Profe Oscar ⚡️ Pregúntame lo que quieras de Swift básico. Si quieres, puedes adjuntar apuntes con el botón 📎 arriba.")
    ]
    @State private var entradaUsuario: String = ""
    @State private var generando: Bool = false
    @State private var estadoModelo: String = "Cargando modelo..."

    @State private var archivosCargados: [ArchivoUsuarioDemo] = []
    @State private var mostrarSelector: Bool = false
    @State private var procesandoArchivos: Bool = false

    @StateObject private var motor = MotorAgenteDemo()

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                encabezado
                if !archivosCargados.isEmpty || procesandoArchivos { tirasArchivos }
                Divider()
                listaMensajes
                Divider()
                barraEntrada
            }
            .navigationTitle("⚡️ Profe Oscar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button { mostrarSelector = true } label: {
                        Image(systemName: "paperclip")
                    }
                    .help("Adjuntar archivos al agente")
                    .disabled(procesandoArchivos)
                }
            }
            .fileImporter(
                isPresented: $mostrarSelector,
                allowedContentTypes: [.plainText, .pdf, .image, UTType(filenameExtension: "md") ?? .plainText],
                allowsMultipleSelection: true
            ) { resultado in
                manejarArchivos(resultado)
            }
        }
        .task { await cargarModelo() }
    }

    private var encabezado: some View {
        HStack {
            Circle()
                .fill(motor.listo ? .green : .orange)
                .frame(width: 10, height: 10)
            Text(estadoModelo)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if !motor.listo && motor.cargandoProgreso > 0 {
                ProgressView(value: motor.cargandoProgreso)
                    .frame(width: 100)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private var tirasArchivos: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(archivosCargados) { archivo in
                    HStack(spacing: 4) {
                        Image(systemName: "doc.text")
                        Text(archivo.nombre)
                            .font(.caption)
                            .lineLimit(1)
                        Button {
                            archivosCargados.removeAll { $0.id == archivo.id }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.15))
                    .clipShape(Capsule())
                }
                if procesandoArchivos {
                    HStack(spacing: 6) {
                        ProgressView().scaleEffect(0.7)
                        Text("Procesando…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange.opacity(0.15))
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
        }
    }

    private var listaMensajes: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(conversacion) { msg in
                        BurbujaMensajeDemo(mensaje: msg).id(msg.id)
                    }
                }
                .padding()
            }
            .onChange(of: conversacion.last?.texto) { _, _ in
                if let ultimo = conversacion.last {
                    withAnimation { proxy.scrollTo(ultimo.id, anchor: .bottom) }
                }
            }
        }
    }

    private var barraEntrada: some View {
        HStack(spacing: 8) {
            TextField("Pregúntale al Profe Oscar...", text: $entradaUsuario, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(!motor.listo || generando)

            Button {
                Task { await enviarMensaje() }
            } label: {
                Image(systemName: generando ? "ellipsis.circle.fill" : "paperplane.fill")
                    .font(.title2)
            }
            .disabled(entradaUsuario.trimmingCharacters(in: .whitespaces).isEmpty || !motor.listo || generando)
        }
        .padding()
    }

    private func cargarModelo() async {
        estadoModelo = "⏳ Descargando / cargando modelo..."
        await motor.cargar(configuracion: modeloDemo)
        estadoModelo = motor.listo ? "✅ Modelo listo" : "❌ No se pudo cargar el modelo"
    }

    private func manejarArchivos(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .success(let urls):
            procesandoArchivos = true
            Task.detached(priority: .userInitiated) {
                var nuevos: [ArchivoUsuarioDemo] = []
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let contenido = leerArchivoDemo(url) {
                        nuevos.append(ArchivoUsuarioDemo(
                            nombre: url.lastPathComponent,
                            contenido: contenido
                        ))
                    }
                }
                await MainActor.run {
                    self.archivosCargados.append(contentsOf: nuevos)
                    self.procesandoArchivos = false
                }
            }
        case .failure(let error):
            print("Error al importar: \(error)")
        }
    }

    private func enviarMensaje() async {
        let texto = entradaUsuario.trimmingCharacters(in: .whitespaces)
        guard !texto.isEmpty, motor.listo, !generando else { return }

        conversacion.append(MensajeDemo(rol: .usuario, texto: texto))
        entradaUsuario = ""
        generando = true

        let idRespuesta = UUID()
        conversacion.append(MensajeDemo(id: idRespuesta, rol: .agente, texto: ""))

        let contextoArchivos = archivosCargados.isEmpty
            ? ""
            : "\n\nARCHIVOS DEL USUARIO:\n" + archivosCargados.map {
                "📄 \($0.nombre):\n\($0.contenido)"
            }.joined(separator: "\n---\n")

        let promptSistema = """
        \(identidadDemo)

        Usa la siguiente información como tu fuente de verdad:
        ---
        \(contextoDemo)
        \(contextoArchivos)
        ---
        Si la pregunta no se relaciona con esta información, dilo claramente.
        """

        await motor.generar(
            sistema: promptSistema,
            pregunta: texto
        ) { fragmento in
            if let idx = conversacion.firstIndex(where: { $0.id == idRespuesta }) {
                conversacion[idx].agregarFragmento(fragmento)
            }
        }

        generando = false
    }
}


// MARK: - Lectura de archivos para la demo
// Usa los helpers globales `ocrDeCGImage` y `cargarCGImageDesdeURL`
// definidos en VistaEnVivo.swift.

func leerArchivoDemo(_ url: URL) -> String? {
    let ext = url.pathExtension.lowercased()

    // Imágenes y capturas → OCR con Apple Vision
    if ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "bmp"].contains(ext) {
        guard let cg = cargarCGImageDesdeURL(url) else { return nil }
        return ocrDeCGImage(cg)
    }

    // PDF → texto nativo + fallback OCR si es escaneado
    if ext == "pdf" {
        return PDFKitWrapperDemo.cargar(url: url)
    }

    // .txt / .md / lo demás → texto plano
    if let texto = try? String(contentsOf: url, encoding: .utf8) {
        return texto
    }

    return nil
}


// MARK: - Modelos de datos (sufijo "Demo")

struct ArchivoUsuarioDemo: Identifiable, Equatable {
    let id = UUID()
    let nombre: String
    let contenido: String
}

struct MensajeDemo: Identifiable, Equatable {
    enum Rol { case usuario, agente }
    let id: UUID
    let rol: Rol
    var texto: String
    var pensamiento: String
    var pensandoAhora: Bool
    var bufferRaw: String

    init(id: UUID = UUID(), rol: Rol, texto: String = "") {
        self.id = id
        self.rol = rol
        self.texto = texto
        self.pensamiento = ""
        self.pensandoAhora = false
        self.bufferRaw = texto
    }

    mutating func agregarFragmento(_ frag: String) {
        bufferRaw += frag
        let r = MensajeDemo.dividirThink(bufferRaw)
        self.texto = r.afuera
        self.pensamiento = r.think
        self.pensandoAhora = r.dentroDeThink
    }

    static func dividirThink(_ s: String) -> (afuera: String, think: String, dentroDeThink: Bool) {
        var afuera = ""
        var think = ""
        var rest = s[...]
        var dentro = false
        while !rest.isEmpty {
            if !dentro {
                if let r = rest.range(of: "<think>") {
                    afuera += rest[..<r.lowerBound]
                    rest = rest[r.upperBound...]
                    dentro = true
                } else {
                    afuera += rest
                    break
                }
            } else {
                if let r = rest.range(of: "</think>") {
                    think += rest[..<r.lowerBound]
                    rest = rest[r.upperBound...]
                    dentro = false
                } else {
                    think += rest
                    break
                }
            }
        }
        return (afuera.trimmingCharacters(in: .whitespacesAndNewlines),
                think.trimmingCharacters(in: .whitespacesAndNewlines),
                dentro)
    }
}


// MARK: - Burbujas con razonamiento visible

struct BurbujaMensajeDemo: View {
    let mensaje: MensajeDemo
    @State private var verPensamiento: Bool = false

    var body: some View {
        HStack {
            if mensaje.rol == .usuario { Spacer(minLength: 40) }

            VStack(alignment: .leading, spacing: 6) {
                if mensaje.rol == .agente && (!mensaje.pensamiento.isEmpty || mensaje.pensandoAhora) {
                    DisclosureGroup(isExpanded: $verPensamiento) {
                        Text(mensaje.pensamiento.isEmpty ? "…" : mensaje.pensamiento)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.yellow.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: mensaje.pensandoAhora ? "brain.head.profile" : "brain")
                            Text(mensaje.pensandoAhora ? "🧠 Pensando…" : "🧠 Cómo lo razonó")
                                .font(.caption.weight(.medium))
                        }
                    }
                }

                if !mensaje.texto.isEmpty || mensaje.rol == .usuario {
                    Text(mensaje.texto.isEmpty ? "…" : mensaje.texto)
                        .padding(10)
                        .background(mensaje.rol == .usuario
                                    ? Color.accentColor.opacity(0.85)
                                    : Color.gray.opacity(0.2))
                        .foregroundStyle(mensaje.rol == .usuario ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .textSelection(.enabled)
                }
            }

            if mensaje.rol == .agente { Spacer(minLength: 40) }
        }
    }
}


// MARK: - PDFKit wrapper con OCR fallback (versión Demo)

#if canImport(PDFKit)
import PDFKit

enum PDFKitWrapperDemo {

    static func cargar(url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }

        // 1) Intento rápido: texto nativo del PDF
        var textoNativo = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let s = page.string {
                textoNativo += s + "\n"
            }
        }

        let umbral = max(200, doc.pageCount * 40)
        if textoNativo.count >= umbral {
            print("📄 [Demo] PDF leído con PDFKit (\(textoNativo.count) chars)")
            return textoNativo
        }

        // 2) Fallback: OCR página por página
        print("📄 [Demo] PDFKit sacó poco texto (\(textoNativo.count) chars). Probando OCR...")
        var textoOCR = ""
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i),
                  let cg = renderizarPagina(page) else { continue }
            if let txt = ocrDeCGImage(cg) {
                textoOCR += "--- Página \(i + 1) ---\n\(txt)\n"
            }
        }

        if !textoOCR.isEmpty {
            print("📄 [Demo] PDF leído con OCR (\(textoOCR.count) chars)")
            return textoOCR
        }

        return textoNativo.isEmpty ? nil : textoNativo
    }

    /// Rasteriza una página de PDF a CGImage. Sube `escala` a 3.0 si la letra es muy chica.
    private static func renderizarPagina(_ page: PDFPage) -> CGImage? {
        let bounds = page.bounds(for: .mediaBox)
        let escala: CGFloat = 2.0
        let ancho = Int(bounds.width * escala)
        let alto = Int(bounds.height * escala)

        guard ancho > 0, alto > 0 else { return nil }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let ctx = CGContext(
            data: nil,
            width: ancho,
            height: alto,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: ancho, height: alto))
        ctx.scaleBy(x: escala, y: escala)

        page.draw(with: .mediaBox, to: ctx)
        return ctx.makeImage()
    }
}
#else
enum PDFKitWrapperDemo {
    static func cargar(url: URL) -> String? { nil }
}
#endif


// MARK: - Motor MLX para la demo

@MainActor
final class MotorAgenteDemo: ObservableObject {

    @Published var listo: Bool = false
    @Published var cargandoProgreso: Double = 0

    private var session: ChatSession?

    func cargar(configuracion: ModelConfiguration) async {
        guard session == nil else { listo = true; return }
        MLX.GPU.set(cacheLimit: 20 * 1024 * 1024)
        do {
            let container = try await #huggingFaceLoadModelContainer(
                configuration: configuracion
            )
            session = ChatSession(container)
            listo = true
        } catch {
            print("❌ Error cargando modelo: \(error)")
            listo = false
        }
    }

    func generar(
        sistema: String,
        pregunta: String,
        onToken: @escaping (String) -> Void
    ) async {
        guard let session else { return }
        let promptCompleto = "\(sistema)\n\nPregunta del usuario: \(pregunta)"
        do {
            for try await fragmento in session.streamResponse(to: promptCompleto) {
                onToken(fragmento)
            }
        } catch {
            print("❌ Error generando: \(error)")
            onToken("\n[error: \(error.localizedDescription)]")
        }
    }
}

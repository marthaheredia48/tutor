// VistaEnVivo.swift
// Tutor
//
// Created by Martha Heredia Andrade on 16/05/26.
//
// ╔══════════════════════════════════════════════════════════════════════╗
// ║ 🎓 TALLER EN VIVO — "¿Necesitas un tutor que te ayude?"              ║
// ║                                                                      ║
// ║ Sigue los 4 BLOQUES marcados con ▼▼▼.                                ║
// ║                                                                      ║
// ║ BLOQUE 1 → IDENTIDAD                                                 ║
// ║ BLOQUE 2 → MODELO                                                    ║
// ║ BLOQUE 3 → CONTEXTO (+ archivos del usuario)                         ║
// ║ BLOQUE 4 → SYSTEM PROMPT (ensamblaje final)                          ║
// ╚══════════════════════════════════════════════════════════════════════╝

import SwiftUI
import UniformTypeIdentifiers

// ⚠️ NO toques estos imports.
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


// MARK: - ▼▼▼ BLOQUE 1 — IDENTIDAD ▼▼▼
//
// 👉 PASO 1: Borra /* y */ para activar `identidadAgente`.
//            Luego reescribe el texto con la identidad de TU tutor.

/*
let identidadAgente = """
Eres "MateBot", un tutor amigable de matemáticas para estudiantes de prepa.
Explicas con ejemplos cotidianos y usas analogías. Respondes siempre en español.
"""
*/


// MARK: - ▼▼▼ BLOQUE 2 — MODELO ▼▼▼
//
// 👉 PASO 2: Borra // de UNA sola línea (la que mejor le quede a tu equipo).
//
//   qwen3_1_7b_4bit → ~1 GB   · iPhone / descarga rápida
//   qwen3_4b_4bit   → ~2.5 GB · ⭐ Mac M2/M3 (recomendado)
//   qwen3_8b_4bit   → ~5 GB   · Mac con 16+ GB de RAM

// let modeloElegido = LLMRegistry.qwen3_1_7b_4bit
// let modeloElegido = LLMRegistry.qwen3_4b_4bit
// let modeloElegido = LLMRegistry.qwen3_8b_4bit


// MARK: - ▼▼▼ BLOQUE 3 — CONTEXTO ▼▼▼
//
// 👉 PASO 3: Borra /* y */ para activar `contextoExperto`.
//            Reemplaza el contenido con la "fuente de verdad" de tu tutor.
//
// 📎 Los archivos que suba el usuario en vivo (botón paperclip) se
//    conectan SOLOS en el Bloque 4. Aquí solo defines el contexto fijo.

/*
let contextoExperto = """
TEMA: Álgebra básica.

CONCEPTOS CLAVE:
- Una ecuación es una igualdad con una incógnita (ej: 2x + 3 = 7).
- Para despejar x: lo que suma pasa restando, lo que multiplica pasa dividiendo.

EJEMPLO RESUELTO:
  2x + 3 = 7
  → 2x = 7 - 3
  → 2x = 4
  → x = 2

ERROR COMÚN:
- Olvidar cambiar el signo al mover un término al otro lado del igual.

FUERA DE ALCANCE:
- Cálculo, geometría avanzada, estadística. Si te preguntan eso, avisa.
"""
*/


// MARK: - ▼▼▼ BLOQUE 4 — SYSTEM PROMPT (ensamblaje) ▼▼▼
//
// El system prompt junta las 4 piezas:
//   IDENTIDAD + CONTEXTO + ARCHIVOS DEL USUARIO + PREGUNTA
//
// 👉 Los pasos 4.1 y 4.2 están más abajo, dentro de `enviarMensaje()`.


struct VistaEnVivo: View {
    @State private var conversacion: [Mensaje] = []
    @State private var entradaUsuario: String = ""
    @State private var generando: Bool = false
    @State private var estadoModelo: String = "Modelo no cargado"

    @State private var archivosCargados: [ArchivoUsuario] = []
    @State private var mostrarSelector: Bool = false
    @State private var procesandoArchivos: Bool = false

    @StateObject private var motor = MotorAgente()

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
            .navigationTitle("🤖 Mi Tutor")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        mostrarSelector = true
                    } label: {
                        Image(systemName: "paperclip")
                    }
                    .help("Adjuntar archivo para tu tutor")
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

    // MARK: Subvistas

    private var encabezado: some View {
        HStack {
            Circle()
                .fill(motor.listo ? .green : .orange)
                .frame(width: 10, height: 10)
            Text(estadoModelo)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
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
                        BurbujaMensaje(mensaje: msg).id(msg.id)
                    }
                }
                .padding()
            }
            .onChange(of: conversacion.count) { _, _ in
                if let ultimo = conversacion.last {
                    withAnimation { proxy.scrollTo(ultimo.id, anchor: .bottom) }
                }
            }
        }
    }

    private var barraEntrada: some View {
        HStack(spacing: 8) {
            TextField("Escribe tu pregunta...", text: $entradaUsuario, axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(1...4)
                .disabled(!motor.listo || generando)

            Button {
                Task { await enviarMensaje() }
            } label: {
                Image(systemName: generando ? "stop.circle.fill" : "paperplane.fill")
                    .font(.title2)
            }
            .disabled(entradaUsuario.trimmingCharacters(in: .whitespaces).isEmpty || !motor.listo || generando)
        }
        .padding()
    }

    // MARK: - Carga del modelo

    private func cargarModelo() async {
        estadoModelo = "⏳ Descargando / cargando modelo..."

        // 👉 PASO 2 (cont.): Borra // de la siguiente línea después de elegir
        //                   `modeloElegido` arriba.
        // await motor.cargar(configuracion: modeloElegido)

        estadoModelo = motor.listo
            ? "✅ Modelo listo — empieza a chatear"
            : "⚠️ Falta elegir y cargar un modelo (Bloque 2)"
    }

    // MARK: - Manejo de archivos cargados por el usuario

    private func manejarArchivos(_ resultado: Result<[URL], Error>) {
        switch resultado {
        case .success(let urls):
            procesandoArchivos = true
            Task.detached(priority: .userInitiated) {
                var nuevos: [ArchivoUsuario] = []
                for url in urls {
                    guard url.startAccessingSecurityScopedResource() else { continue }
                    defer { url.stopAccessingSecurityScopedResource() }
                    if let contenido = leerArchivoDesdeURL(url) {
                        nuevos.append(ArchivoUsuario(
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
}

// MARK: - Lectura de archivos (.txt / .md / imágenes / PDFs)

func leerArchivoDesdeURL(_ url: URL) -> String? {
    let ext = url.pathExtension.lowercased()

    if ["jpg", "jpeg", "png", "heic", "heif", "tiff", "gif", "bmp"].contains(ext) {
        guard let cg = cargarCGImageDesdeURL(url) else { return nil }
        return ocrDeCGImage(cg)
    }

    if ext == "pdf" {
        return PDFKitWrapper.cargar(url: url)
    }

    if let texto = try? String(contentsOf: url, encoding: .utf8) {
        return texto
    }
    return nil
}

// MARK: - Modelos de datos

struct ArchivoUsuario: Identifiable, Equatable {
    let id = UUID()
    let nombre: String
    let contenido: String
}

struct Mensaje: Identifiable, Equatable {
    enum Rol { case usuario, agente }
    let id: UUID
    let rol: Rol
    var texto: String          // respuesta visible (fuera de <think>)
    var pensamiento: String    // contenido dentro de <think>...</think>
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

    // Separa la respuesta pública del razonamiento interno <think>...</think>
    // para mostrarlo en el panel "🧠 Cómo lo razonó".
    mutating func agregarFragmento(_ frag: String) {
        bufferRaw += frag
        let r = Mensaje.dividirThink(bufferRaw)
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

// MARK: - Burbujas con panel colapsable "🧠 cómo está pensando"

struct BurbujaMensaje: View {
    let mensaje: Mensaje
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
                        .background(mensaje.rol == .usuario ? Color.accentColor.opacity(0.85) : Color.gray.opacity(0.2))
                        .foregroundStyle(mensaje.rol == .usuario ? .white : .primary)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .textSelection(.enabled)
                }
            }

            if mensaje.rol == .agente { Spacer(minLength: 40) }
        }
    }
}

// MARK: - Envío de mensaje

extension VistaEnVivo {
    fileprivate func enviarMensaje() async {
        let texto = entradaUsuario.trimmingCharacters(in: .whitespaces)
        guard !texto.isEmpty, motor.listo, !generando else { return }

        conversacion.append(Mensaje(rol: .usuario, texto: texto))
        entradaUsuario = ""
        generando = true

        let idRespuesta = UUID()
        conversacion.append(Mensaje(id: idRespuesta, rol: .agente, texto: ""))

        // ────────────────────────────────────────────────────────────────
        // 👉 PASO 4.1 — SYSTEM PROMPT
        // Borra /* y */ para ensamblar:
        //   IDENTIDAD + CONTEXTO + ARCHIVOS DEL USUARIO
        // ────────────────────────────────────────────────────────────────

        /*
        let contextoArchivos = archivosCargados.isEmpty
            ? ""
            : "\n\nARCHIVOS DEL USUARIO:\n" + archivosCargados.map {
                "📄 \($0.nombre):\n\($0.contenido)"
            }.joined(separator: "\n---\n")

        let promptSistema = """
        \(identidadAgente)

        Usa la siguiente información como tu fuente de verdad:
        ---
        \(contextoExperto)
        \(contextoArchivos)
        ---
        Si la pregunta no se relaciona con esta información, dilo claramente.
        """
        */

        // ────────────────────────────────────────────────────────────────
        // 👉 PASO 4.2 — GENERAR RESPUESTA
        // Borra /* y */ para enviar el prompt al motor y recibir tokens en vivo.
        // ────────────────────────────────────────────────────────────────

        /*
        await motor.generar(
            sistema: promptSistema,
            pregunta: texto
        ) { fragmento in
            if let idx = conversacion.firstIndex(where: { $0.id == idRespuesta }) {
                conversacion[idx].agregarFragmento(fragmento)
            }
        }
        */

        // ❌ BORRA este bloque cuando descomentes los pasos 4.1 y 4.2 ❌
        if let idx = conversacion.firstIndex(where: { $0.id == idRespuesta }) {
            conversacion[idx].texto = "(Aún no conecto los bloques 1–4. Descomenta los pasos 4.1 y 4.2 🙂)"
        }
        // ❌ FIN del bloque a borrar ❌

        generando = false
    }
}

// MARK: - PDFKit wrapper con OCR fallback
// Texto nativo del PDF primero; si está escaneado, rasteriza y aplica OCR.

#if canImport(PDFKit)
import PDFKit

enum PDFKitWrapper {
    static func cargar(url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }

        var textoNativo = ""
        for i in 0..<doc.pageCount {
            if let page = doc.page(at: i), let s = page.string {
                textoNativo += s + "\n"
            }
        }

        let umbral = max(200, doc.pageCount * 40)
        if textoNativo.count >= umbral {
            print("📄 PDF leído con PDFKit (\(textoNativo.count) chars)")
            return textoNativo
        }

        print("📄 PDFKit sacó poco texto (\(textoNativo.count) chars). Probando OCR...")
        var textoOCR = ""
        for i in 0..<doc.pageCount {
            guard let page = doc.page(at: i),
                  let cg = renderizarPagina(page) else { continue }
            if let txt = ocrDeCGImage(cg) {
                textoOCR += "--- Página \(i + 1) ---\n\(txt)\n"
            }
        }

        if !textoOCR.isEmpty {
            print("📄 PDF leído con OCR (\(textoOCR.count) chars)")
            return textoOCR
        }

        return textoNativo.isEmpty ? nil : textoNativo
    }

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
enum PDFKitWrapper {
    static func cargar(url: URL) -> String? { nil }
}
#endif

// MARK: - OCR helpers (Apple Vision, 100% local)

func ocrDeCGImage(_ cgImage: CGImage) -> String? {
    let request = VNRecognizeTextRequest()
    request.recognitionLevel = .accurate
    request.usesLanguageCorrection = true
    request.recognitionLanguages = ["es-ES", "en-US"]

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    do {
        try handler.perform([request])
        guard let obs = request.results else { return nil }
        let lineas = obs.compactMap { $0.topCandidates(1).first?.string }
        let texto = lineas.joined(separator: "\n")
        return texto.isEmpty ? nil : texto
    } catch {
        print("Error de OCR: \(error)")
        return nil
    }
}

func cargarCGImageDesdeURL(_ url: URL) -> CGImage? {
    #if os(iOS)
    guard let data = try? Data(contentsOf: url),
          let uiImage = UIImage(data: data) else { return nil }
    return uiImage.cgImage
    #else
    guard let nsImage = NSImage(contentsOf: url) else { return nil }
    var rect = CGRect(x: 0, y: 0, width: nsImage.size.width, height: nsImage.size.height)
    return nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil)
    #endif
}

// MARK: - Motor MLX (ya implementado — no necesitas tocarlo)

@MainActor
final class MotorAgente: ObservableObject {
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

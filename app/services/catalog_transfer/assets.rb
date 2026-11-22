require "digest"
require "stringio"

module CatalogTransfer
  class Assets
    NAME = /\Aasset-[a-f0-9]{64}\.bin\z/
    MAX_FILE_BYTES = 25.megabytes
    MAX_TOTAL_BYTES = 250.megabytes

    attr_reader :files

    def initialize(files = {})
      @files = files
      @exported = {}
      @imported = {}
      @uploads = AttachmentUploadBatch.new
      @byte_size = files.values.sum(&:bytesize)
    end

    def export(blob)
      @exported[blob.id] ||= begin
        if blob.byte_size > MAX_FILE_BYTES || @byte_size + blob.byte_size > MAX_TOTAL_BYTES
          raise Error, "目录附件超过单个 25 MB 或总计 250 MB 的限制。"
        end
        bytes = blob.download
        name = "asset-#{Digest::SHA256.hexdigest(bytes)}.bin"
        unless @files.key?(name)
          @files[name] = bytes
          @byte_size += bytes.bytesize
        end
        { "file" => name, "filename" => blob.filename.to_s, "content_type" => blob.content_type }
      end
    rescue ActiveStorage::FileNotFoundError
      raise Error, "找不到目录附件 #{blob.filename}，请补传或移除损坏的附件。"
    end

    def import(reference)
      unless reference.is_a?(Hash) && reference["filename"].is_a?(String) &&
          reference["filename"].length.between?(1, 255) && reference["content_type"].is_a?(String)
        raise Error, "目录附件信息无效。"
      end

      name = reference["file"]
      bytes = @files.fetch(name) { raise Error, "目录包缺少所引用的附件。" }
      filename, content_type = reference.values_at("filename", "content_type")
      @imported[[name, filename, content_type]] ||= upload(bytes, filename, content_type)
    end

    def cleanup_failed_uploads
      @uploads.cleanup_failed_uploads
    end

    private

    def upload(bytes, filename, content_type)
      checksum = Digest::MD5.base64digest(bytes)
      candidate = ActiveStorage::Blob.where(checksum: checksum, byte_size: bytes.bytesize, filename: filename).first
      if candidate && candidate.content_type == content_type && candidate.service.exist?(candidate.key) &&
          Digest::SHA256.hexdigest(candidate.download) == Digest::SHA256.hexdigest(bytes)
        return candidate
      end

      io = StringIO.new(bytes)
      blob = ActiveStorage::Blob.build_after_unfurling(io: io, filename: filename, content_type: content_type)
      blob.save!
      @uploads.upload(blob, io)
    end
  end
end

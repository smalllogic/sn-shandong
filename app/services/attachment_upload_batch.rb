class AttachmentUploadBatch
  def initialize
    @uploaded = []
  end

  def upload(blob, io)
    @uploaded << blob
    blob.upload_without_unfurling(io)
    blob
  end

  def cleanup_failed_uploads
    @uploaded.each do |blob|
      # Check after rollback so a committed attachment is never deleted.
      blob.service.delete(blob.key) unless ActiveStorage::Blob.exists?(key: blob.key)
    rescue StandardError => error
      Rails.logger.error("Attachment cleanup failed: #{error.class}")
    end
  end
end

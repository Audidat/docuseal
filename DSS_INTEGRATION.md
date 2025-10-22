# DSS Service Integration for LTA Signatures

This document describes the integration between DocuSeal and the DSS (Digital Signature Service) for extending PDF signatures to PAdES-BASELINE-LTA level.

## Overview

DocuSeal uses HexaPDF to create PAdES signatures. After signing, the DSS service is called to extend the signature to **PAdES-BASELINE-LTA** (Long Term Archive) level, which adds:

- Archive timestamp
- Revocation data (CRL/OCSP)
- Long-term validation information

This ensures signatures remain valid even after certificates expire.

## Configuration

### Environment Variables

```bash
# DSS Service URL (required to enable LTA extension)
DSS_SERVICE_URL=http://localhost:4000

# Optional: Disable LTA extension by not setting DSS_SERVICE_URL
# DSS_SERVICE_URL=
```

### Docker Compose Development

The DSS service is already configured in `docker-compose.dev.yml`:

```yaml
services:
  app:
    environment:
      - SIGNATURE_TYPE=pades
      - DSS_SERVICE_URL=http://dss-service:4000

  dss-service:
    build:
      context: ../dss_service
      dockerfile: Dockerfile.dev
    ports:
      - "4000:4000"
    environment:
      - P12_PATH=cotelmur.p12
      - P12_PASSWORD=02484012
      - TSA_URL=http://timestamp.digicert.com
```

**Note:** Update `P12_PATH` and `P12_PASSWORD` with your certificate details.

## How It Works

### Signing Flow

1. **User completes submission** → DocuSeal creates PDF with signature fields
2. **HexaPDF signs PDF** → Creates PAdES-B or PAdES-BT signature
3. **DSS extends to LTA** → Calls `/api/extend` endpoint with signed PDF
4. **Result saved** → LTA-extended PDF stored as final document

### Code Flow

```ruby
# lib/submissions/generate_result_attachments.rb (line 701-708)

pdf.sign(io, **sign_params)           # Step 1: HexaPDF signs the PDF
maybe_enable_ltv(io, sign_params)     # Step 2: Extend to LTA via DSS

# lib/submissions/dss_ltv_extension.rb
DssLtvExtension.extend_to_lta(io)     # Calls DSS /api/extend endpoint
```

### Integration Points

The `maybe_enable_ltv` method is called in 3 places:

1. **`generate_result_attachments.rb:708`** - Final signed documents
2. **`generate_combined_attachment.rb:33`** - Combined PDF attachments
3. **`generate_audit_trail.rb:54`** - Audit trail PDFs

All signed PDFs automatically get LTA extension when DSS service is configured.

## Graceful Fallback

If the DSS service is:
- **Not configured** (`DSS_SERVICE_URL` not set) → No LTA extension, original PDF used
- **Unavailable** (network error, timeout) → Logs error, uses original PDF
- **Returns error** (400/500 status) → Logs error, uses original PDF

**This ensures DocuSeal continues working even if DSS service is down.**

## Testing

### Using Docker Compose (Recommended)

```bash
# From the docuseal directory
cd /path/to/electronic_signature/docuseal

# Start all services (DocuSeal + DSS + Postgres + Redis)
docker compose -f docker-compose.dev.yml up

# Or rebuild if you changed dependencies
docker compose -f docker-compose.dev.yml up --build

# View logs
docker compose -f docker-compose.dev.yml logs -f app
docker compose -f docker-compose.dev.yml logs -f dss-service
```

### Using Standalone Services

#### 1. Start DSS Service

```bash
cd dss_service
export P12_PATH=/path/to/certificate.p12
export P12_PASSWORD=your_password
clj -M:run
```

#### 2. Configure DocuSeal

```bash
export DSS_SERVICE_URL=http://localhost:4000
bin/dev
```

### 3. Create and Sign a Document

1. Create a template with signature field
2. Submit and complete the signature
3. Check Rails logs for DSS extension:

```
[DSS LTV Extension] Calling DSS extend service at http://localhost:4000/api/extend
[DSS LTV Extension] DSS extend service succeeded (123456 bytes)
```

### 4. Verify LTA Signature

Download the signed PDF and verify with:
- Adobe Acrobat Reader (should show LTV-enabled signature)
- DSS Demo App: https://ec.europa.eu/digital-building-blocks/DSS/webapp-demo
- PDF-Tools or similar signature validators

Expected: **PAdES-BASELINE-LTA** signature level

## Troubleshooting

### DSS Service Not Being Called

**Check:**
```bash
# Is DSS_SERVICE_URL set?
echo $DSS_SERVICE_URL

# Is DSS service running?
curl http://localhost:4000/health
```

**Rails logs should show:**
```
[DSS LTV Extension] Calling DSS extend service at http://localhost:4000/api/extend
```

### DSS Service Returns Error

**Check DSS logs:**
```bash
# In DSS service directory
# Look for errors about certificate, TSA, or PDF processing
```

**Common issues:**
- P12 certificate not found or invalid password
- TSA (timestamp authority) unreachable
- Malformed input PDF

### Timeout Errors

**Increase timeout in `dss_ltv_extension.rb`:**
```ruby
http.read_timeout = 120  # Increase from 60 to 120 seconds
```

LTA extension can be slow due to:
- TSA timestamp requests
- CRL/OCSP revocation checks
- Network latency

## File Changes Summary

### Modified Files

1. **`lib/submissions/generate_result_attachments.rb`**
   - Line 3: Added `require_relative 'dss_ltv_extension'`
   - Lines 730-734: Modified `maybe_enable_ltv` to call DSS service

### New Files

2. **`lib/submissions/dss_ltv_extension.rb`**
   - DSS HTTP client
   - Error handling and logging
   - Configuration management

3. **`DSS_INTEGRATION.md`** (this file)
   - Documentation

## Merge Strategy

When updating DocuSeal from upstream:

### Expected Conflicts

**`lib/submissions/generate_result_attachments.rb`:**
- Line 3: `require_relative` statement (easy to re-add)
- Lines 730-734: `maybe_enable_ltv` method (easy to re-apply)

### Resolution

If DocuSeal updates `maybe_enable_ltv`:

```ruby
# Their version (upstream):
def maybe_enable_ltv(io, _sign_params)
  # New DocuSeal implementation here
  io
end

# Our version (keep this):
def maybe_enable_ltv(io, _sign_params)
  # Extend PDF to PAdES-BASELINE-LTA using DSS service if configured
  # Falls back to original PDF if DSS is unavailable or disabled
  DssLtvExtension.extend_to_lta(io) || io
end
```

**Strategy:** Keep our version, incorporate their changes into `DssLtvExtension` if needed.

### No Conflicts Expected

- `lib/submissions/dss_ltv_extension.rb` - New file, won't conflict
- `DSS_INTEGRATION.md` - Documentation, won't conflict

## Performance Impact

**Signing time increase:**
- Without DSS: ~1-2 seconds (HexaPDF signing)
- With DSS: ~3-7 seconds (HexaPDF + DSS LTA extension)

**Additional time breakdown:**
- HTTP request/response: ~50-100ms
- TSA timestamp: ~1-2 seconds
- OCSP/CRL validation: ~1-3 seconds
- PDF processing: ~100-500ms

**Mitigation:**
- DSS operations happen in background jobs (no user impact)
- Graceful fallback ensures no blocking on errors
- Can be disabled per-environment if needed

## Security Considerations

1. **Network Security**
   - DSS service should be on private network
   - Use HTTPS in production (`DSS_SERVICE_URL=https://dss.internal:4000`)
   - Consider firewall rules to restrict access

2. **Certificate Security**
   - DSS service P12 certificate must be secured
   - Use environment variables or secrets management
   - Never commit certificates to git

3. **Validation**
   - LTA signatures can be validated without trusting original signer
   - Archive timestamps prove signature existed before certificate expiry
   - Revocation data embedded in PDF for offline validation

## References

- [ETSI EN 319 142 (PAdES)](https://www.etsi.org/deliver/etsi_en/319100_319199/31914202/01.01.01_60/en_31914202v010101p.pdf)
- [EU DSS Documentation](https://ec.europa.eu/digital-building-blocks/wikis/display/DIGITAL/Digital+Signature+Service)
- [HexaPDF Signing](https://hexapdf.gettalong.org/documentation/digital-signatures/)
- [DSS Service API](../dss_service/API.md)

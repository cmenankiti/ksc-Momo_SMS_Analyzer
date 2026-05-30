# MoMo SMS Analyzer — API Documentation

**Team KSC** · Chigozirim Menankiti · Samuel Nizeyimana · Mamashenge Kendra  
**Version:** 1.0 · **Base URL:** `http://localhost:8080`

---

## Authentication

All endpoints require **HTTP Basic Authentication**.

| Header | Format |
|---|---|
| `Authorization` | `Basic <base64(username:password)>` |

**Valid credentials:**

| Username | Password | Role |
|---|---|---|
| `admin` | `ksc_admin123` | Full access (CRUD) |
| `analyst` | `ksc_read456` | Read access |

**curl example:**
```bash
curl -u admin:ksc_admin123 http://localhost:8080/transactions
```

Missing or invalid credentials return `401 Unauthorized`.

---

## Error Codes

| Code | Meaning | When |
|---|---|---|
| `200 OK` | Success | GET / PUT / DELETE |
| `201 Created` | Resource created | POST |
| `400 Bad Request` | Malformed request / bad ID | Invalid ID format, bad JSON |
| `401 Unauthorized` | Auth failed | Wrong or missing credentials |
| `404 Not Found` | Resource missing | ID doesn't exist, bad route |
| `422 Unprocessable Entity` | Validation failed | Missing required fields, bad values |

---

## Endpoints

---

### `GET /transactions`

List all transactions parsed from the XML source file.

**Request**
```bash
curl -u admin:ksc_admin123 http://localhost:8080/transactions
```

**Response — 200 OK**
```json
{
  "status": "success",
  "count": 25,
  "transactions": [
    {
      "id": 1,
      "externalTransactionId": "TXN20250103001",
      "transactionType": "Incoming",
      "transactionStatus": "Completed",
      "amount": 50000.0,
      "fee": 0.0,
      "balanceAfter": 320000.0,
      "currency": "RWF",
      "senderName": "Alice Uwimana",
      "receiverName": null,
      "phoneNumber": "0788100001",
      "transactionDate": "2025-01-03T08:15:22",
      "rawMessage": "You have received 50,000 RWF from Alice Uwimana (0788100001). ...",
      "createdAt": "2026-05-30T10:24:39Z"
    }
  ]
}
```

---

### `GET /transactions/{id}`

Retrieve a single transaction by its integer ID.

**Request**
```bash
curl -u admin:ksc_admin123 http://localhost:8080/transactions/5
```

**Response — 200 OK**
```json
{
  "status": "success",
  "transaction": {
    "id": 5,
    "externalTransactionId": "TXN20250111005",
    "transactionType": "Airtime",
    "transactionStatus": "Completed",
    "amount": 2000.0,
    "fee": 0.0,
    "balanceAfter": 247590.0,
    "currency": "RWF",
    "transactionDate": "2025-01-11T16:40:00",
    "rawMessage": "You have purchased 2,000 RWF airtime for 0788100001. ...",
    "createdAt": "2026-05-30T10:24:39Z"
  }
}
```

**Response — 404 Not Found**
```json
{
  "error": "Not Found",
  "message": "Transaction 99 not found."
}
```

---

### `POST /transactions`

Create a new transaction record.

**Required fields:**

| Field | Type | Description |
|---|---|---|
| `transactionType` | string | One of: `Incoming`, `Transfer`, `Withdrawal`, `Payment`, `Airtime`, `Bank_Deposit`, `Bundle_Purchase` |
| `amount` | number | Positive amount in RWF |
| `rawMessage` | string | Original SMS body text |

**Optional fields:** `fee`, `balanceAfter`, `senderName`, `receiverName`, `phoneNumber`, `transactionDate`

**Request**
```bash
curl -u admin:ksc_admin123 \
  -X POST \
  -H "Content-Type: application/json" \
  -d '{
    "transactionType": "Transfer",
    "amount": 12000,
    "fee": 100,
    "senderName": "Test Admin",
    "receiverName": "Test User",
    "rawMessage": "RWF 12,000 transferred to Test User (0788999999). Fee: RWF 100. New balance: 150,000 RWF. TxnID: TXN20250301026."
  }' \
  http://localhost:8080/transactions
```

**Response — 201 Created**
```json
{
  "status": "created",
  "transaction": {
    "id": 26,
    "transactionType": "Transfer",
    "transactionStatus": "Completed",
    "amount": 12000.0,
    "fee": 100,
    "senderName": "Test Admin",
    "receiverName": "Test User",
    "currency": "RWF",
    "createdAt": "2026-05-30T10:24:41Z"
  }
}
```

**Response — 422 Unprocessable Entity** (missing fields)
```json
{
  "error": "Unprocessable Entity",
  "message": "Missing required fields: transactionType, rawMessage"
}
```

---

### `PUT /transactions/{id}`

Update one or more fields of an existing transaction. Immutable fields (`id`, `createdAt`, `externalTransactionId`) are silently ignored.

**Request**
```bash
curl -u admin:ksc_admin123 \
  -X PUT \
  -H "Content-Type: application/json" \
  -d '{"transactionStatus": "Pending", "fee": 120}' \
  http://localhost:8080/transactions/26
```

**Response — 200 OK**
```json
{
  "status": "updated",
  "transaction": {
    "id": 26,
    "transactionType": "Transfer",
    "transactionStatus": "Pending",
    "amount": 12000.0,
    "fee": 120,
    "updatedAt": "2026-05-30T10:24:41Z"
  }
}
```

**Response — 404 Not Found**
```json
{
  "error": "Not Found",
  "message": "Transaction 26 not found."
}
```

---

### `DELETE /transactions/{id}`

Permanently delete a transaction from the in-memory store.

**Request**
```bash
curl -u admin:ksc_admin123 \
  -X DELETE \
  http://localhost:8080/transactions/26
```

**Response — 200 OK**
```json
{
  "status": "deleted",
  "message": "Transaction 26 successfully deleted."
}
```

**Response — 404 Not Found**
```json
{
  "error": "Not Found",
  "message": "Transaction 26 not found."
}
```

---

## Transaction Type Reference

| Type | Description | Is Income |
|---|---|---|
| `Incoming` | Money received from another MoMo account or bank | ✅ |
| `Transfer` | Money sent to another MoMo user | ❌ |
| `Withdrawal` | Cash withdrawn at an agent | ❌ |
| `Payment` | Merchant or bill payment | ❌ |
| `Airtime` | Airtime top-up purchase | ❌ |
| `Bank_Deposit` | Transfer to a bank account | ❌ |
| `Bundle_Purchase` | Internet bundle purchase | ❌ |

---

## Quick Reference — All Endpoints

| Method | Endpoint | Auth | Description |
|---|---|---|---|
| `GET` | `/` | ✅ | API info & available routes |
| `GET` | `/transactions` | ✅ | List all transactions |
| `GET` | `/transactions/{id}` | ✅ | Get one transaction |
| `POST` | `/transactions` | ✅ | Create a transaction |
| `PUT` | `/transactions/{id}` | ✅ | Update a transaction |
| `DELETE` | `/transactions/{id}` | ✅ | Delete a transaction |

resource "aws_opensearchserverless_security_policy" "encryption" {
  name        = "rag-vectorstore-encrypt"
  type        = "encryption"
  description = "Encryption policy for rag-vectorstore"

  policy = jsonencode({
    Rules = [
      {
        Resource = [
          "collection/rag-vectorstore"
        ],
        ResourceType = "collection"
      }
    ],
    AWSOwnedKey = true
  })
}


resource "aws_opensearchserverless_collection" "rag_vectorstore" {
  name = "rag-vectorstore"
  type = "VECTORSEARCH"

  depends_on = [
    aws_opensearchserverless_security_policy.encryption
  ]
}

resource "aws_opensearchserverless_security_policy" "network" {
  name        = "rag-vectorstore-network"
  type        = "network"
  description = "Network policy for rag-vectorstore"

  policy = jsonencode([
    {
      Rules = [
        {
          ResourceType = "collection",
          Resource     = ["collection/rag-vectorstore"]
        }
      ],
      AllowFromPublic = true
    }
  ])
}

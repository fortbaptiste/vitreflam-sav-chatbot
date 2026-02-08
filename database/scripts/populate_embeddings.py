"""
VITREFLAM - Script de generation des embeddings
Popule la knowledge_base et response_templates avec les embeddings OpenAI

Usage:
    pip install supabase openai python-dotenv
    python populate_embeddings.py
"""

import os
from dotenv import load_dotenv
from supabase import create_client, Client
from openai import OpenAI

# Charger les variables d'environnement
load_dotenv()

# Configuration
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_SERVICE_KEY")  # Utiliser service key pour bypass RLS
OPENAI_API_KEY = os.getenv("OPENAI_API_KEY")

# Modele d'embedding OpenAI (1536 dimensions)
EMBEDDING_MODEL = "text-embedding-ada-002"

# Initialisation clients
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
openai_client = OpenAI(api_key=OPENAI_API_KEY)


def generate_embedding(text: str) -> list[float]:
    """
    Genere un embedding pour un texte donne.
    Utilise OpenAI ada-002 (1536 dimensions).
    """
    response = openai_client.embeddings.create(
        model=EMBEDDING_MODEL,
        input=text
    )
    return response.data[0].embedding


def populate_knowledge_base():
    """
    Genere les embeddings pour tous les documents de la knowledge_base
    qui n'ont pas encore d'embedding.
    """
    print("=== Mise a jour Knowledge Base ===")

    # Recuperer les documents sans embedding
    result = supabase.table("knowledge_base") \
        .select("id, contenu, categorie") \
        .is_("embedding", "null") \
        .execute()

    documents = result.data
    print(f"Documents a traiter: {len(documents)}")

    for i, doc in enumerate(documents):
        try:
            # Generer l'embedding du contenu
            embedding = generate_embedding(doc["contenu"])

            # Mettre a jour le document
            supabase.table("knowledge_base") \
                .update({"embedding": embedding}) \
                .eq("id", doc["id"]) \
                .execute()

            print(f"  [{i+1}/{len(documents)}] {doc['categorie']}: OK")

        except Exception as e:
            print(f"  [{i+1}/{len(documents)}] ERREUR: {e}")

    print("Knowledge Base: TERMINE\n")


def populate_response_templates():
    """
    Genere les embeddings pour tous les templates de reponse
    qui n'ont pas encore d'embedding.
    """
    print("=== Mise a jour Response Templates ===")

    # Recuperer les templates sans embedding
    result = supabase.table("response_templates") \
        .select("id, code, template") \
        .is_("embedding", "null") \
        .execute()

    templates = result.data
    print(f"Templates a traiter: {len(templates)}")

    for i, tpl in enumerate(templates):
        try:
            # Generer l'embedding du template
            embedding = generate_embedding(tpl["template"])

            # Mettre a jour le template
            supabase.table("response_templates") \
                .update({"embedding": embedding}) \
                .eq("id", tpl["id"]) \
                .execute()

            print(f"  [{i+1}/{len(templates)}] {tpl['code']}: OK")

        except Exception as e:
            print(f"  [{i+1}/{len(templates)}] ERREUR: {e}")

    print("Response Templates: TERMINE\n")


def test_search(query: str, limit: int = 3):
    """
    Teste la recherche semantique dans la knowledge base.
    """
    print(f"=== Test Recherche: '{query}' ===")

    # Generer l'embedding de la requete
    query_embedding = generate_embedding(query)

    # Appeler la fonction RPC de recherche
    result = supabase.rpc(
        "search_knowledge",
        {
            "query_embedding": query_embedding,
            "match_threshold": 0.7,
            "match_count": limit
        }
    ).execute()

    print(f"Resultats ({len(result.data)}):")
    for r in result.data:
        print(f"  - [{r['similarity']:.2f}] {r['categorie']}/{r['sous_categorie']}")
        print(f"    {r['contenu'][:100]}...")
    print()


def main():
    """
    Script principal.
    """
    print("\n" + "="*50)
    print("VITREFLAM - Population des Embeddings")
    print("="*50 + "\n")

    # Verifier la configuration
    if not all([SUPABASE_URL, SUPABASE_KEY, OPENAI_API_KEY]):
        print("ERREUR: Variables d'environnement manquantes!")
        print("Creez un fichier .env avec:")
        print("  SUPABASE_URL=https://xxx.supabase.co")
        print("  SUPABASE_SERVICE_KEY=eyJ...")
        print("  OPENAI_API_KEY=sk-...")
        return

    # Populer les embeddings
    populate_knowledge_base()
    populate_response_templates()

    # Tests de recherche
    print("=== Tests de Recherche Semantique ===\n")
    test_search("mon verre est arrive casse")
    test_search("comment prendre les mesures")
    test_search("quel est le delai de livraison")

    print("="*50)
    print("TERMINE!")
    print("="*50)


if __name__ == "__main__":
    main()

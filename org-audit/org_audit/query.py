"""GraphQL query + cursor pagination for fetching repos and branch protection state."""
from .gh import run_graphql

_REPO_FIELDS = """
    name
    isArchived
    isPrivate
    defaultBranchRef {
      name
      branchProtectionRule {
        isAdminEnforced
        allowsForcePushes
        allowsDeletions
        requiresApprovingReviews
        requiredApprovingReviewCount
        requiresCodeOwnerReviews
        requiresCommitSignatures
        requiresStatusChecks
      }
    }
"""

_ORG_QUERY = f"""
query($owner: String!, $first: Int!, $cursor: String) {{
  organization(login: $owner) {{
    repositories(first: $first, after: $cursor) {{
      pageInfo {{ hasNextPage endCursor }}
      nodes {{
{_REPO_FIELDS}
      }}
    }}
  }}
}}
"""

_USER_QUERY = f"""
query($owner: String!, $first: Int!, $cursor: String) {{
  user(login: $owner) {{
    repositories(first: $first, ownerAffiliations: OWNER, after: $cursor) {{
      pageInfo {{ hasNextPage endCursor }}
      nodes {{
{_REPO_FIELDS}
      }}
    }}
  }}
}}
"""


def fetch_repos(owner: str, owner_type: str = "org", page_size: int = 50):
    """Yield every repo dict for `owner`, paginating until exhausted."""
    query = _ORG_QUERY if owner_type == "org" else _USER_QUERY
    root_key = "organization" if owner_type == "org" else "user"

    cursor = None
    while True:
        variables = {"owner": owner, "first": page_size, "cursor": cursor}
        data = run_graphql(query, variables)
        root = data.get(root_key)
        if root is None:
            raise ValueError(
                f"{owner_type} '{owner}' not found or not accessible with current gh auth"
            )
        repos = root["repositories"]
        for node in repos["nodes"]:
            yield node

        page_info = repos["pageInfo"]
        if not page_info["hasNextPage"]:
            break
        cursor = page_info["endCursor"]

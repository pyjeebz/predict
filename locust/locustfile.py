from locust import HttpUser, task, between, events
import random
import json
from datetime import datetime

class SaleorEcommerceUser(HttpUser):
    """
    Simulates user behavior on Saleor e-commerce platform
    Includes browsing, searching, cart operations, and checkout
    """
    
    wait_time = between(1, 5)  # Wait 1-5 seconds between tasks
    
    def on_start(self):
        """Initialize user session"""
        self.product_ids = []
        self.cart_token = None
        self.load_products()
    
    def load_products(self):
        """Load some product IDs for testing"""
        # GraphQL query to get products
        query = """
        query {
            products(first: 20) {
                edges {
                    node {
                        id
                        name
                        slug
                    }
                }
            }
        }
        """
        
        try:
            response = self.client.post(
                "/graphql/",
                json={"query": query},
                name="GraphQL: Get Products"
            )
            
            if response.status_code == 200:
                data = response.json()
                if 'data' in data and 'products' in data['data']:
                    self.product_ids = [
                        edge['node']['id'] 
                        for edge in data['data']['products']['edges']
                    ]
        except Exception as e:
            print(f"Error loading products: {e}")
    
    @task(10)
    def browse_homepage(self):
        """Browse the homepage"""
        self.client.get("/", name="Browse Homepage")
    
    @task(8)
    def browse_products(self):
        """Browse product listings"""
        query = """
        query {
            products(first: 10) {
                edges {
                    node {
                        id
                        name
                        slug
                        thumbnail {
                            url
                        }
                        pricing {
                            priceRange {
                                start {
                                    gross {
                                        amount
                                        currency
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        """
        
        self.client.post(
            "/graphql/",
            json={"query": query},
            name="GraphQL: Browse Products"
        )
    
    @task(6)
    def view_product_detail(self):
        """View a specific product"""
        if not self.product_ids:
            return
        
        product_id = random.choice(self.product_ids)
        
        query = """
        query getProduct($id: ID!) {
            product(id: $id) {
                id
                name
                description
                slug
                category {
                    name
                }
                pricing {
                    priceRange {
                        start {
                            gross {
                                amount
                                currency
                            }
                        }
                    }
                }
                images {
                    url
                }
                variants {
                    id
                    name
                    pricing {
                        price {
                            gross {
                                amount
                                currency
                            }
                        }
                    }
                }
            }
        }
        """
        
        self.client.post(
            "/graphql/",
            json={
                "query": query,
                "variables": {"id": product_id}
            },
            name="GraphQL: View Product Detail"
        )
    
    @task(4)
    def search_products(self):
        """Search for products"""
        search_terms = [
            "shirt", "pants", "shoes", "jacket", "dress",
            "watch", "phone", "laptop", "book", "camera"
        ]
        
        search_term = random.choice(search_terms)
        
        query = """
        query searchProducts($search: String!) {
            products(first: 10, filter: {search: $search}) {
                edges {
                    node {
                        id
                        name
                        slug
                    }
                }
            }
        }
        """
        
        self.client.post(
            "/graphql/",
            json={
                "query": query,
                "variables": {"search": search_term}
            },
            name="GraphQL: Search Products"
        )
    
    @task(3)
    def add_to_cart(self):
        """Add product to cart"""
        if not self.product_ids:
            return
        
        product_id = random.choice(self.product_ids)
        
        # First get product variants
        query = """
        query getProduct($id: ID!) {
            product(id: $id) {
                variants {
                    id
                }
            }
        }
        """
        
        response = self.client.post(
            "/graphql/",
            json={
                "query": query,
                "variables": {"id": product_id}
            },
            name="GraphQL: Get Product Variants"
        )
        
        if response.status_code != 200:
            return
        
        data = response.json()
        if 'data' in data and 'product' in data['data']:
            variants = data['data']['product'].get('variants', [])
            if not variants:
                return
            
            variant_id = variants[0]['id']
            
            # Add to cart
            mutation = """
            mutation addToCart($variantId: ID!, $quantity: Int!) {
                checkoutLinesAdd(
                    lines: [{variantId: $variantId, quantity: $quantity}]
                ) {
                    checkout {
                        id
                        lines {
                            id
                        }
                    }
                    errors {
                        message
                    }
                }
            }
            """
            
            self.client.post(
                "/graphql/",
                json={
                    "query": mutation,
                    "variables": {
                        "variantId": variant_id,
                        "quantity": random.randint(1, 3)
                    }
                },
                name="GraphQL: Add to Cart"
            )
    
    @task(2)
    def view_cart(self):
        """View shopping cart"""
        query = """
        query {
            me {
                checkout {
                    id
                    lines {
                        id
                        quantity
                        variant {
                            product {
                                name
                            }
                        }
                    }
                    totalPrice {
                        gross {
                            amount
                            currency
                        }
                    }
                }
            }
        }
        """
        
        self.client.post(
            "/graphql/",
            json={"query": query},
            name="GraphQL: View Cart"
        )
    
    @task(5)
    def browse_categories(self):
        """Browse product categories"""
        query = """
        query {
            categories(first: 10) {
                edges {
                    node {
                        id
                        name
                        slug
                        products(first: 5) {
                            edges {
                                node {
                                    id
                                    name
                                }
                            }
                        }
                    }
                }
            }
        }
        """
        
        self.client.post(
            "/graphql/",
            json={"query": query},
            name="GraphQL: Browse Categories"
        )


class HighTrafficUser(SaleorEcommerceUser):
    """
    Simulates high traffic scenarios with faster interactions
    """
    wait_time = between(0.5, 2)  # Faster wait time


class PeakHourUser(SaleorEcommerceUser):
    """
    Simulates peak hour behavior with more checkout attempts
    """
    wait_time = between(1, 3)
    
    @task(5)
    def checkout_attempt(self):
        """Attempt to proceed to checkout"""
        query = """
        query {
            me {
                checkout {
                    id
                    availablePaymentGateways {
                        id
                        name
                    }
                    availableShippingMethods {
                        id
                        name
                    }
                }
            }
        }
        """
        
        self.client.post(
            "/graphql/",
            json={"query": query},
            name="GraphQL: Checkout Attempt"
        )


@events.test_start.add_listener
def on_test_start(environment, **kwargs):
    """Hook that runs when the load test starts"""
    print(f"Load test started at {datetime.now()}")
    print(f"Target host: {environment.host}")


@events.test_stop.add_listener
def on_test_stop(environment, **kwargs):
    """Hook that runs when the load test stops"""
    print(f"Load test completed at {datetime.now()}")

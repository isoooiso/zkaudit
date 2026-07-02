use super::*;
use risc0_interface::{
    Receipt, RiscZeroVerifierRouterInterface, VerifierEntry, VerifierError,
};
use soroban_sdk::{
    testutils::Address as _,
    Address, Bytes, BytesN, Env, contract, contractimpl,
};

const JOURNAL_V1_HEX: &str = "1c4426846cccbb0d3823e7bd9feba44f80db11d7f6f9fc23fc7344588a98ee7b40c583061a7be04d18dffc3fc7c7439408ed7c37969432a19f72a3e9ee820d10070000000a000000";
const IMAGE_ID_V1_HEX: &str = "2b421e8181bdefa2deeecd65802cc4771819332d8e142117427bf69d5235cbc0";
const CONTRACT_HASH_V1_HEX: &str = "1c4426846cccbb0d3823e7bd9feba44f80db11d7f6f9fc23fc7344588a98ee7b";
const SUITE_COMMITMENT_HEX: &str = "40c583061a7be04d18dffc3fc7c7439408ed7c37969432a19f72a3e9ee820d10";

mod mock_router {
    use super::*;

    #[contract]
    pub struct MockRouter;

    #[contractimpl]
    impl RiscZeroVerifierRouterInterface for MockRouter {
        fn verify(
            _env: Env,
            _seal: Bytes,
            _image_id: BytesN<32>,
            _journal: BytesN<32>,
        ) -> Result<(), VerifierError> {
            Ok(())
        }

        fn verify_integrity(_env: Env, _receipt: Receipt) -> Result<(), VerifierError> {
            Ok(())
        }

        fn verifiers(_env: Env, _selector: BytesN<4>) -> Option<VerifierEntry> {
            None
        }

        fn get_verifier_by_selector(
            _env: Env,
            _selector: BytesN<4>,
        ) -> Result<Address, VerifierError> {
            Err(VerifierError::InvalidSelector)
        }

        fn get_verifier_from_seal(_env: Env, _seal: Bytes) -> Result<Address, VerifierError> {
            Err(VerifierError::InvalidSelector)
        }
    }
}

fn hex_to_bytesn<const N: usize>(env: &Env, hex_str: &str) -> BytesN<N> {
    let bytes = hex::decode(hex_str).expect("valid hex");
    assert_eq!(bytes.len(), N);
    let mut arr = [0u8; N];
    arr.copy_from_slice(&bytes);
    BytesN::from_array(env, &arr)
}

fn hex_to_bytes(env: &Env, hex_str: &str) -> Bytes {
    let bytes = hex::decode(hex_str).expect("valid hex");
    Bytes::from_slice(env, &bytes)
}

fn setup() -> (Env, Address, Address, Address, AttestationRegistryClient<'static>) {
    let env = Env::default();
    env.mock_all_auths();

    let admin = Address::generate(&env);
    let router_id = env.register(mock_router::MockRouter, ());
    let auditor = Address::generate(&env);
    let contract_id = env.register(AttestationRegistry, (admin.clone(), router_id.clone()));
    let client = AttestationRegistryClient::new(&env, &contract_id);

    (env, admin, router_id, auditor, client)
}

fn register_v1_engine(client: &AttestationRegistryClient) {
    let image_id = hex_to_bytesn(&client.env, IMAGE_ID_V1_HEX);
    client.register_engine(&image_id);
}

#[test]
fn attest_happy_path_stores_journal_v1_fields() {
    let (env, _admin, _router, auditor, client) = setup();
    register_v1_engine(&client);

    let image_id = hex_to_bytesn(&env, IMAGE_ID_V1_HEX);
    let journal = hex_to_bytes(&env, JOURNAL_V1_HEX);
    let seal = Bytes::from_slice(&env, &[0xAB; 8]);

    client.attest(&auditor, &seal, &image_id, &journal);

    let contract_hash = hex_to_bytesn(&env, CONTRACT_HASH_V1_HEX);
    let att = client
        .get_attestation(&contract_hash)
        .expect("attestation stored");

    assert_eq!(att.contract_hash, contract_hash);
    assert_eq!(
        att.suite_commitment,
        hex_to_bytesn(&env, SUITE_COMMITMENT_HEX)
    );
    assert_eq!(att.n_passed, 7);
    assert_eq!(att.n_total, 10);
    assert_eq!(att.image_id, image_id);
    assert_eq!(att.auditor, auditor);
}

#[test]
fn attest_unregistered_engine_returns_error() {
    let (env, _admin, _router, auditor, client) = setup();
    let image_id = hex_to_bytesn(&env, IMAGE_ID_V1_HEX);
    let journal = hex_to_bytes(&env, JOURNAL_V1_HEX);
    let seal = Bytes::from_slice(&env, &[0u8; 4]);

    let result = client.try_attest(&auditor, &seal, &image_id, &journal);
    assert_eq!(result, Err(Ok(Error::EngineNotRegistered)));
}

#[test]
fn attest_bad_journal_len_returns_error() {
    let (env, _admin, _router, auditor, client) = setup();
    register_v1_engine(&client);

    let image_id = hex_to_bytesn(&env, IMAGE_ID_V1_HEX);
    let journal = Bytes::from_slice(&env, &[0u8; 71]);
    let seal = Bytes::from_slice(&env, &[0u8; 4]);

    let result = client.try_attest(&auditor, &seal, &image_id, &journal);
    assert_eq!(result, Err(Ok(Error::BadJournalLen)));
}

#[test]
#[should_panic(expected = "HostError")]
fn register_engine_without_admin_auth_fails() {
    let env = Env::default();
    let admin = Address::generate(&env);
    let router_id = env.register(mock_router::MockRouter, ());
    let contract_id = env.register(AttestationRegistry, (admin, router_id));
    let client = AttestationRegistryClient::new(&env, &contract_id);

    let image_id = hex_to_bytesn(&env, IMAGE_ID_V1_HEX);
    client.register_engine(&image_id);
}

#[test]
fn get_attestation_unknown_hash_returns_none() {
    let (env, _admin, _router, _auditor, client) = setup();
    let unknown = hex_to_bytesn(
        &env,
        "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    );
    assert_eq!(client.get_attestation(&unknown), None);
}

#[test]
fn is_engine_registered_reflects_register_engine() {
    let (env, _admin, _router, _auditor, client) = setup();
    let image_id = hex_to_bytesn(&env, IMAGE_ID_V1_HEX);
    assert!(!client.is_engine_registered(&image_id));
    client.register_engine(&image_id);
    assert!(client.is_engine_registered(&image_id));
}

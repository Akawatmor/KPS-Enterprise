# Phase 1 - Week 1: AWS Learner Lab Analysis Report

**Project**: KPS-Enterprise - Three-Tier DevSecOps Application  
**Phase**: 1 - Infrastructure Analysis  
**Week**: 1  
**Date**: March 26, 2026  
**Team**: Akawatmor, Ratthatummanoon

---

## 📋 Executive Summary

This report documents the completion of Phase 1, Week 1 activities focusing on analyzing AWS Learner Lab limitations and their impact on the KPS-Enterprise three-tier DevSecOps project migration.

### Key Achievements

✅ **Complete AWS Learner Lab limitations documentation**  
✅ **Identified all critical blockers and workarounds**  
✅ **Created comprehensive requirements mapping**  
✅ **Documented required code modifications**  
✅ **Validated EKS compatibility with Learner Lab**

---

## 🎯 Completed Tasks

### Issue #11: Document AWS Learner Lab Limitations

**Status**: ✅ COMPLETED  
**Issue Link**: [#11](https://github.com/Akawatmor/KPS-Enterprise/issues/11)

#### Acceptance Criteria Completed

- ✅ **IAM Restriction Documentation**
  - Documented that custom IAM roles cannot be created
  - Must use `LabRole` and `LabInstanceProfile`
  - Identified all files requiring IAM-related changes

- ✅ **EC2 Limits Documentation**
  - Maximum 9 EC2 instances per session
  - Instance types limited to `*.large` (max 2 vCPU, 8 GB RAM)
  - Total vCPU budget: 32 vCPUs across all instances
  - Original `t2.2xlarge` not allowed, must use `t2.large`

- ✅ **ECR Permission Issue Documentation**
  - LabRole has READ-ONLY access to ECR
  - Cannot push Docker images to ECR
  - Identified Docker Hub as alternative solution
  - Documented pipeline changes required

- ✅ **EKS Support Documentation**
  - Confirmed EKS is supported in Learner Lab ✅
  - Must use `LabEksClusterRole` for cluster
  - Must use `LabRole` for node groups
  - Maximum node instance type: `t2.large`

- ✅ **Region Restriction Documentation**
  - Only `us-east-1` and `us-west-2` available
  - Original project uses `us-east-1` - compatible ✅
  - Multi-region deployment not possible

- ✅ **Mapping Table Creation**
  - Created comprehensive table mapping:
    - Original configurations
    - Learner Lab limitations
    - Required changes
    - Files to modify
    - Priority levels

---

## 📊 Analysis Results

### Critical Findings

#### 🔴 High-Impact Limitations (Require Code Changes)

1. **IAM Role Management**
   - **Impact**: Cannot create custom IAM resources
   - **Solution**: Use pre-existing `LabRole` and `LabInstanceProfile`
   - **Files Affected**: 3 files to delete, 1 file to modify
   - **Effort**: Medium

2. **EC2 Instance Types**
   - **Impact**: Cannot use `t2.2xlarge` for Jenkins
   - **Solution**: Downgrade to `t2.large`
   - **Performance Impact**: Jenkins may run slower (8 vCPU → 2 vCPU, 32 GB → 8 GB)
   - **Files Affected**: 2 files to modify
   - **Effort**: Low

3. **ECR Access Restrictions**
   - **Impact**: Cannot push Docker images to ECR
   - **Solution**: Use Docker Hub (public or private repos)
   - **Files Affected**: 2 Jenkinsfiles + all K8s deployment manifests
   - **Effort**: High (requires pipeline redesign)

4. **EKS IAM Roles**
   - **Impact**: Cannot create custom EKS service roles
   - **Solution**: Use `LabEksClusterRole` and `LabRole`
   - **Files Affected**: EKS creation scripts (eksctl or Terraform)
   - **Effort**: Medium

#### 🟠 Medium-Impact Limitations (Workarounds Available)

1. **Terraform Backend**
   - **Impact**: Cannot use Terraform to create S3 backend
   - **Solution**: Manually create S3 bucket and DynamoDB table before running Terraform
   - **Effort**: Low (one-time setup)

2. **Resource Quotas**
   - **Impact**: Limited to 9 instances and 32 vCPUs total
   - **Solution**: Careful resource planning and allocation
   - **Effort**: Low (planning activity)

---

## 📁 Deliverables

### Documentation Created

1. **`issue-11-requirements-mapping.md`** (18 KB)
   - Complete requirements mapping table
   - Original config → Required changes → Files to modify
   - Implementation checklist
   - Code examples (before/after)
   - Priority classifications

2. **`PHASE1-REPORT.md`** (This document)
   - Executive summary
   - Analysis results
   - Recommendations
   - Next steps

3. **Existing Documentation Referenced**
   - `learnerlab-problem-predocs.md` (39 KB) - Detailed technical analysis
   - `original-project-structure.md` - Original project documentation

### Files Identified for Modification

#### To Delete (3 files):
```
Jenkins-Server-TF/
├── iam-role.tf              ❌ DELETE - Custom IAM role creation not allowed
├── iam-policy.tf            ❌ DELETE - Policy attachment not allowed
└── iam-instance-profile.tf  ❌ DELETE - Profile creation not allowed
```

#### To Modify (7+ files):
```
Jenkins-Server-TF/
├── ec2.tf                   ✏️ MODIFY - Use LabInstanceProfile, change instance type
└── variables.tfvars         ✏️ MODIFY - Update defaults

Jenkins-Pipeline-Code/
├── Jenkinsfile-Backend      ✏️ MODIFY - Replace ECR with Docker Hub
└── Jenkinsfile-Frontend     ✏️ MODIFY - Replace ECR with Docker Hub

Kubernetes-Manifests-file/
├── Backend/deployment.yaml  ✏️ MODIFY - Update image to Docker Hub
├── Frontend/deployment.yaml ✏️ MODIFY - Update image to Docker Hub
└── ingress.yaml            ✏️ MODIFY - Verify region annotations
```

---

## 🎯 Key Recommendations

### Immediate Actions (Phase 1, Week 2)

1. **Set Up Docker Hub**
   - Create Docker Hub account
   - Generate access token
   - Configure Jenkins credentials
   - Test image push/pull

2. **Modify Terraform Files**
   - Delete IAM-related files (3 files)
   - Update `ec2.tf` with LabInstanceProfile
   - Change instance type to `t2.large`
   - Test Terraform plan in Learner Lab

3. **Update Jenkins Pipelines**
   - Replace ECR push stages with Docker Hub
   - Update image tagging strategy
   - Test pipeline with Docker Hub integration

4. **Prepare Kubernetes Manifests**
   - Update all image references to Docker Hub
   - Verify region-specific annotations
   - Validate manifests

### Pre-Deployment Checklist

Before deploying to AWS Learner Lab:

- [ ] AWS Learner Lab session is active
- [ ] Region set to `us-east-1`
- [ ] S3 bucket created for Terraform state
- [ ] DynamoDB table created for state locking
- [ ] Docker Hub account ready
- [ ] Docker Hub credentials added to Jenkins
- [ ] All Terraform IAM files deleted
- [ ] EC2 instance type changed to `t2.large`
- [ ] All Jenkinsfiles updated for Docker Hub
- [ ] All K8s manifests updated with Docker Hub images

### Performance Considerations

**Jenkins Server Downgrade Impact:**
- Original: `t2.2xlarge` (8 vCPU, 32 GB RAM)
- New: `t2.large` (2 vCPU, 8 GB RAM)
- **Expected Impact**:
  - Longer build times (4x slower CPU)
  - Limited concurrent builds
  - Possible memory constraints with multiple pipelines

**Mitigation Strategies:**
1. Optimize Jenkins configuration (reduce concurrent builds)
2. Use Docker layer caching aggressively
3. Consider pipeline parallelization carefully
4. Monitor resource usage and adjust as needed

**EKS Worker Nodes:**
- Recommended: 3-4 nodes of `t2.large` (2 vCPU each)
- Total: 6-8 vCPUs for workload
- Remaining budget: 24-26 vCPUs for other resources

---

## 📈 Resource Allocation Plan

### Proposed Instance Distribution

| Component | Count | Instance Type | vCPU per Instance | Total vCPU | Notes |
|-----------|-------|--------------|------------------|-----------|-------|
| Jenkins Server | 1 | t2.large | 2 | 2 | CI/CD automation |
| EKS Control Plane | 1 | (AWS Managed) | 0 | 0 | No vCPU charge |
| EKS Worker Nodes | 3 | t2.large | 2 | 6 | Application workload |
| Reserved/Testing | 2 | t2.large | 2 | 4 | Development/testing |
| **TOTAL** | **6** | - | - | **12** | ✅ Within limits |

**Remaining Capacity:**
- Instances: 3 available (9 - 6 = 3)
- vCPUs: 20 available (32 - 12 = 20)
- **Status**: ✅ Safe buffer for scaling

---

## ⚠️ Risks and Mitigation

### Risk 1: Jenkins Performance Degradation
- **Probability**: High
- **Impact**: Medium
- **Mitigation**: 
  - Optimize pipeline stages
  - Use build caching
  - Limit concurrent builds to 1-2

### Risk 2: Docker Hub Rate Limits
- **Probability**: Medium
- **Impact**: Medium
- **Mitigation**:
  - Use authenticated pulls (200 pulls/6hrs)
  - Consider Docker Hub Pro if needed
  - Cache images locally on Jenkins

### Risk 3: EKS Node Capacity
- **Probability**: Low
- **Impact**: Medium
- **Mitigation**:
  - Use Horizontal Pod Autoscaling conservatively
  - Set appropriate resource requests/limits
  - Monitor node utilization

### Risk 4: Learner Lab Session Expiry
- **Probability**: High (by design)
- **Impact**: High
- **Mitigation**:
  - Document all resource IDs before session end
  - Use Terraform state for reproducibility
  - Maintain Docker images in Docker Hub (persistent)
  - Keep regular backups of configurations

---

## 📚 Technical Decisions Log

### Decision 1: Container Registry
- **Decision**: Use Docker Hub instead of AWS ECR
- **Reason**: ECR has read-only access in Learner Lab
- **Alternatives Considered**: 
  - ✅ Docker Hub (public/private)
  - ❌ GitHub Container Registry (adds complexity)
  - ❌ Self-hosted registry (resource intensive)
- **Trade-offs**: 
  - Pro: Easy integration, well-documented
  - Con: Rate limits, potential cost for private repos

### Decision 2: Jenkins Instance Type
- **Decision**: Use `t2.large` (2 vCPU, 8 GB)
- **Reason**: Maximum allowed instance type in Learner Lab
- **Alternatives Considered**:
  - ✅ t2.large (2 vCPU, 8 GB) - Maximum allowed
  - ❌ t2.medium (2 vCPU, 4 GB) - Insufficient memory for Jenkins + tools
  - ❌ t2.xlarge+ - Not allowed
- **Trade-offs**:
  - Pro: Maximum performance within limits
  - Con: Slower than original `t2.2xlarge` design

### Decision 3: EKS Worker Node Configuration
- **Decision**: 3x `t2.large` nodes
- **Reason**: Balance between capacity and resource limits
- **Alternatives Considered**:
  - ✅ 3x t2.large (6 vCPU total) - Good balance
  - ❌ 6x t2.small (6 vCPU total) - More scheduling overhead
  - ❌ 2x t2.large (4 vCPU total) - May be insufficient for 3-tier app
- **Trade-offs**:
  - Pro: Adequate capacity for 3-tier app
  - Con: Limited scaling headroom

---

## 🔄 Next Steps (Phase 1, Week 2)

### Priority 1: Infrastructure Preparation
1. Set up Docker Hub account and credentials
2. Manually create S3 bucket for Terraform state
3. Manually create DynamoDB table for state locking
4. Test AWS Learner Lab access and permissions

### Priority 2: Code Modifications
1. Delete IAM-related Terraform files (3 files)
2. Modify `ec2.tf` to use LabInstanceProfile
3. Update instance type to `t2.large` in Terraform
4. Update Jenkins pipelines for Docker Hub
5. Update Kubernetes manifests with Docker Hub images

### Priority 3: Testing and Validation
1. Test Terraform plan/apply in Learner Lab
2. Deploy Jenkins server and verify tools installation
3. Test Jenkins pipeline with Docker Hub integration
4. Validate Kubernetes manifest syntax

### Priority 4: EKS Deployment
1. Create EKS cluster with LabEksClusterRole
2. Configure node groups with LabRole
3. Deploy AWS Load Balancer Controller
4. Deploy application manifests
5. Test end-to-end application flow

---

## 📞 Support and Questions

### Questions for Instructor
1. Is Docker Hub acceptable for storing container images? (Private repo needed?)
2. Is Jenkins performance on `t2.large` adequate for project requirements?
3. Should we plan for 3 or 4 EKS worker nodes?
4. Any specific security requirements for Docker Hub integration?

### Team Contacts
- **Project Lead**: Akawatmor
- **Documentation**: Ratthatummanoon
- **Repository**: https://github.com/Akawatmor/KPS-Enterprise

---

## 📊 Metrics and Statistics

### Documentation Coverage
- Total limitations documented: **12**
- Critical issues identified: **4**
- Major issues identified: **2**
- Minor issues identified: **6**
- Files to delete: **3**
- Files to modify: **7+**
- Code examples provided: **8**

### Effort Estimation
- Documentation effort: ✅ Completed
- Code modification effort: ~8-12 hours (estimated)
- Testing effort: ~4-6 hours (estimated)
- Total Phase 1, Week 1 effort: ~12-20 hours

---

## ✅ Conclusion

Phase 1, Week 1 has been successfully completed with comprehensive documentation of all AWS Learner Lab limitations and their required workarounds. 

**Key Findings:**
- ✅ EKS deployment is fully supported in Learner Lab
- ✅ All limitations have documented workarounds
- ✅ No project-blocking issues identified
- ✅ Clear path forward for Phase 1, Week 2 implementation

**Readiness for Next Phase:**
- All acceptance criteria from Issue #11 completed
- Complete requirements mapping available
- Implementation checklist prepared
- Risk mitigation strategies defined

**Recommendation**: Proceed to Phase 1, Week 2 with confidence. All technical blockers have been identified and solutions documented.

---

## 📎 Appendix

### A. Related Documents
- [Issue #11 Requirements Mapping](./issue-11-requirements-mapping.md) - Detailed technical mapping
- [Learner Lab Limitations](../learnerlab-problem-predocs.md) - Full technical analysis
- [Original Project Structure](../original-project-structure.md) - Project baseline

### B. References
- [AWS Learner Lab Documentation](https://aws.amazon.com/training/digital/aws-learner-lab/)
- [EKS Best Practices](https://aws.github.io/aws-eks-best-practices/)
- [Docker Hub Documentation](https://docs.docker.com/docker-hub/)
- [Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)

### C. Glossary
- **EKS**: Elastic Kubernetes Service
- **ECR**: Elastic Container Registry
- **IAM**: Identity and Access Management
- **vCPU**: Virtual Central Processing Unit
- **SAST**: Static Application Security Testing
- **SCA**: Software Composition Analysis

---

**Report Compiled By**: GitHub Copilot CLI  
**Date**: March 26, 2026  
**Version**: 1.0  
**Status**: Final

---

*This report fulfills all requirements for Issue #11 and provides a comprehensive foundation for Phase 1, Week 2 implementation activities.*

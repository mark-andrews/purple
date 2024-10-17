The connection between a **finite radial basis function (RBF) network** and a **Gaussian Process (GP)** can be understood as the finite RBF network becoming a GP as the number of basis functions approaches infinity. The key idea is that when we assume that the weights of the RBF network are drawn from a Gaussian distribution, in the limit of an infinite number of basis functions, the resulting function distribution becomes a GP.

### Setup: RBF Network

Consider a radial basis function network with \( m \) basis functions:

\[
f(x) = \sum_{i=1}^{m} w_i \phi(x, c_i)
\]

Where:
- \( \phi(x, c_i) \) is the radial basis function centered at \( c_i \), often chosen as a Gaussian:
  \[
  \phi(x, c_i) = \exp\left(-\frac{(x - c_i)^2}{2 \ell^2}\right)
  \]
  where \( \ell \) is the length scale.
- \( w_i \) are the weights of the network.
- \( c_i \) are the centers of the radial basis functions.
- \( m \) is the number of basis functions.

### Assumptions:
1. The weights \( w_i \) are independent and identically distributed (i.i.d.) according to a Gaussian distribution:
   \[
   w_i \sim \mathcal{N}(0, \sigma_w^2)
   \]
2. The centers \( c_i \) are either fixed or sampled randomly from some distribution.

### Step 1: Compute the Mean and Covariance of the Function

The function \( f(x) \) is a linear combination of the basis functions with Gaussian weights. We will compute the mean and covariance of \( f(x) \) as a stochastic process.

#### 1.1: Mean Function

The mean function of \( f(x) \) is:

\[
\mathbb{E}[f(x)] = \mathbb{E}\left[\sum_{i=1}^{m} w_i \phi(x, c_i)\right]
\]

Since \( w_i \sim \mathcal{N}(0, \sigma_w^2) \), we have \( \mathbb{E}[w_i] = 0 \). Therefore, the expected value of \( f(x) \) is:

\[
\mathbb{E}[f(x)] = \sum_{i=1}^{m} \mathbb{E}[w_i] \phi(x, c_i) = 0
\]

So the mean function is zero, i.e.,

\[
\mathbb{E}[f(x)] = 0
\]

#### 1.2: Covariance Function

The covariance between two function values \( f(x) \) and \( f(x') \) is:

\[
\text{Cov}(f(x), f(x')) = \mathbb{E}[f(x) f(x')] - \mathbb{E}[f(x)]\mathbb{E}[f(x')] = \mathbb{E}[f(x) f(x')]
\]

Since \( \mathbb{E}[f(x)] = 0 \), the covariance becomes:

\[
\text{Cov}(f(x), f(x')) = \mathbb{E}\left[\left( \sum_{i=1}^{m} w_i \phi(x, c_i) \right) \left( \sum_{j=1}^{m} w_j \phi(x', c_j) \right)\right]
\]

Expanding this:

\[
\text{Cov}(f(x), f(x')) = \sum_{i=1}^{m} \sum_{j=1}^{m} \mathbb{E}[w_i w_j] \phi(x, c_i) \phi(x', c_j)
\]

Since \( w_i \) and \( w_j \) are independent for \( i \neq j \), and \( \mathbb{E}[w_i^2] = \sigma_w^2 \), this simplifies to:

\[
\text{Cov}(f(x), f(x')) = \sum_{i=1}^{m} \sigma_w^2 \phi(x, c_i) \phi(x', c_i)
\]

### Step 2: Infinite Limit of the RBF Network

Now, consider what happens as \( m \to \infty \). If the centers \( c_i \) are sampled randomly from some distribution (e.g., uniformly over the input space), the sum:

\[
\sum_{i=1}^{m} \phi(x, c_i) \phi(x', c_i)
\]

can be approximated by an integral as \( m \to \infty \):

\[
\sum_{i=1}^{m} \phi(x, c_i) \phi(x', c_i) \approx m \int \phi(x, c) \phi(x', c) p(c) dc
\]

where \( p(c) \) is the probability distribution from which the centers \( c_i \) are drawn.

Thus, the covariance between \( f(x) \) and \( f(x') \) in the infinite limit becomes:

\[
\text{Cov}(f(x), f(x')) = \sigma_w^2 m \int \phi(x, c) \phi(x', c) p(c) dc
\]

For radial basis functions such as Gaussian kernels, this integral can be shown to correspond to a Gaussian kernel (squared exponential kernel) with length scale \( \ell \), resulting in the following covariance function:

\[
k(x, x') = \exp\left(-\frac{(x - x')^2}{2 \ell^2}\right)
\]

This is exactly the covariance function of a **Gaussian Process** with an RBF kernel.

### Step 3: Gaussian Process as the Infinite Limit

As \( m \to \infty \), the finite RBF network converges to a Gaussian Process because:
- The sum of infinitely many Gaussian random variables (the weights \( w_i \)) leads to a Gaussian distribution over functions (via the **Central Limit Theorem**).
- The covariance function of the resulting GP is the **RBF kernel** (or squared exponential kernel), which describes the covariance between function values based on the distance between input points.

### Conclusion:

In the **limit of infinitely many basis functions** \( m \to \infty \), the finite RBF network with Gaussian-distributed weights \( w_i \) converges to a **Gaussian Process**. The covariance structure of the GP is determined by the RBF kernel, which is equivalent to the covariance of the infinite RBF network.

Thus, a **Gaussian Process** is the **infinite limit of a finite RBF network**, where the weights \( w_i \) are Gaussian and the number of basis functions tends to infinity. This connection highlights how Gaussian Processes can be viewed as an infinite-dimensional extension of certain types of neural networks.


The idea that a **Gaussian Process (GP)** is the **infinite limit of a finite Radial Basis Function (RBF) network** is well-established in machine learning and statistics. This connection, often referred to as the relationship between **Bayesian neural networks** (BNNs) and GPs, is discussed in several classical papers and textbooks. Here are some key references that delve into this topic, including proofs and theoretical explanations:

### 1. **"Neal, Radford M. (1996). Bayesian Learning for Neural Networks."**
   - **Citation**: Neal, R. M. (1996). *Bayesian Learning for Neural Networks* (Vol. 118). Springer Science & Business Media.
   - **Link**: [Neal's Thesis on Bayesian Learning for Neural Networks](https://www.cs.toronto.edu/~radford/ftp/thesis.pdf)
   
   This is one of the foundational works on the relationship between neural networks (including radial basis function networks) and Gaussian Processes. In this work, Radford Neal shows that a single-layer neural network with infinitely many hidden units and Gaussian priors over the weights converges to a GP.

   Neal's result generalizes to networks using other basis functions, such as RBFs. The thesis provides both the mathematical derivation and theoretical background behind this relationship. Chapter 2 of Neal’s thesis lays out the proof of how the infinite hidden unit limit of a neural network converges to a GP.

### 2. **"Gaussian Processes for Machine Learning" by Carl Edward Rasmussen and Christopher K. I. Williams (2006)**
   - **Citation**: Rasmussen, C. E., & Williams, C. K. I. (2006). *Gaussian Processes for Machine Learning*. MIT Press.
   - **Link**: [Online version of the book](http://www.gaussianprocess.org/gpml/)
   
   In this book, the authors describe in detail the relationship between radial basis functions and Gaussian Processes in Chapter 4. The book discusses how neural networks with infinitely many hidden units can be interpreted as Gaussian Processes and provides mathematical explanations for how the covariance functions of GPs arise from such neural networks.

   Specifically, the relationship between **Radial Basis Function networks** and GPs is touched upon in the context of kernel machines, and the squared exponential kernel is derived in the context of infinite basis functions.

### 3. **"Infinite Neural Networks as Gaussian Processes" (Williams, 1997)**
   - **Citation**: Williams, C. K. I. (1997). *Computing with Infinite Networks*. In *Neural Information Processing Systems* (NIPS), 1996.
   - **Link**: [Williams Paper on Infinite Networks and GPs](http://www.gatsby.ucl.ac.uk/~williams/me.html)
   
   In this paper, Chris Williams specifically addresses how neural networks with infinitely many units behave as Gaussian Processes. This is one of the seminal papers that establishes the connection formally and is often cited as a core reference in the field.

   The paper provides a derivation of how the covariance function of a GP emerges from the limit of an infinite network of basis functions.

### 4. **"Deep Learning" by Ian Goodfellow, Yoshua Bengio, and Aaron Courville (2016)**
   - **Citation**: Goodfellow, I., Bengio, Y., & Courville, A. (2016). *Deep Learning*. MIT Press.
   - **Link**: [Deep Learning Book Online](https://www.deeplearningbook.org/)
   
   Chapter 6 of this book touches on **Radial Basis Function Networks** and how they relate to GPs. While the book is primarily focused on deep learning, it also provides insights into how RBF networks with infinitely many basis functions converge to GPs, particularly in the context of kernel methods.

### Key Takeaway

The most detailed proof of the convergence of a finite RBF network to a Gaussian Process can be found in Radford Neal's 1996 Ph.D. thesis and Chris Williams' 1997 paper. These works rigorously demonstrate how a neural network (and by extension, an RBF network) becomes a GP as the number of hidden units or basis functions goes to infinity.

Let me know if you'd like more specific pointers to sections or further details from any of these references!